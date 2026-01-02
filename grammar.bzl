def _get_package_name(file):
    # Calculates package name based on path relative to src/main/antlr4
    path = file.short_path
    if "src/main/antlr4/" in path:
        rel_path = path.split("src/main/antlr4/")[1]
        dir_path = rel_path.rpartition("/")[0]
        return dir_path.replace("/", ".")
    return ""

def _get_output_dir_path(file):
     # Calculates directory path relative to src/main/antlr4
    path = file.short_path
    if "src/main/antlr4/" in path:
        rel_path = path.split("src/main/antlr4/")[1]
        return rel_path.rpartition("/")[0]
    return ""

def _antlr_gen_impl(ctx):
    srcs = ctx.files.srcs
    tool = ctx.executable.tool
    java_runtime = ctx.toolchains["@bazel_tools//tools/jdk:toolchain_type"].java.java_runtime
    jar_tool = java_runtime.java_home + "/bin/jar"
    
    # 1. Create Lib Dir components using symlinks
    lib_files = []
    lib_dir_path = ctx.label.name + "_lib"
    
    for f in srcs:
        symlink_out = ctx.actions.declare_file(lib_dir_path + "/" + f.basename)
        ctx.actions.symlink(output = symlink_out, target_file = f)
        lib_files.append(symlink_out)

    # Filter sources
    lexers = []
    parsers = []
    
    for f in srcs:
        if "/core/" in f.short_path or f.basename.endswith("CoreParserGrammar.g4"):
            continue
            
        if "Lexer" in f.basename:
            lexers.append(f)
        else:
            parsers.append(f)

    # Keep track of all generated source dirs to zip later
    all_gen_dirs = []
    generated_tokens = []

    # 2. Compile Lexers
    for lexer in lexers:
        package = _get_package_name(lexer)
        rel_dir = _get_output_dir_path(lexer)
        
        out_dir = ctx.actions.declare_directory(ctx.label.name + "_lexer_out_" + lexer.basename)
        all_gen_dirs.append(out_dir)
        
        args = ctx.actions.args()
        args.add("-package", package)
        args.add("-visitor")
        args.add("-listener")
        # Point -lib to the directory containing symlinked grammars
        args.add("-lib", lib_files[0].dirname)
        args.add("-o", out_dir.path + "/" + rel_dir)
        # Input file is the symlink
        # For the input file, it is in lib_files[0] directory.
        # We can construct path: lib_files[0].dirname + "/" + lexer.basename
        # Or just use the artifact if we found it in lib_files?
        # But lib_files contains symlinks with correct names.
        # We should find the specific artifact in lib_files that corresponds to lexer.
        # However, for simplicity, using path format is easier.
        args.add(lib_files[0].dirname + "/" + lexer.basename)

        ctx.actions.run(
            outputs = [out_dir],
            inputs = lib_files,
            executable = tool,
            arguments = [args],
            mnemonic = "AntlrLexer",
            progress_message = "Compiling Lexer " + lexer.basename,
        )
        
        generated_tokens.append(out_dir)

    # 3. Update Lib with Tokens (Phase 2)
    lib_phase2_dir = ctx.actions.declare_directory(ctx.label.name + "_lib_phase2")
    
    phase2_args = ctx.actions.args()
    phase2_args.add(lib_files[0].dirname)   # Source of .g4 symlinks
    phase2_args.add(lib_phase2_dir.path)    # Dest dir
    phase2_args.add_all(generated_tokens)   # Dirs containing .tokens
    
    ctx.actions.run_shell(
        inputs = lib_files + generated_tokens,
        outputs = [lib_phase2_dir],
        arguments = [phase2_args],
        command = """
            src_lib_dir="$1"
            dest_lib="$2"
            shift 2
            mkdir -p "$dest_lib"
            cp "$src_lib_dir"/*.g4 "$dest_lib"/
            for token_dir in "$@"; do
                find "$token_dir" -name '*.tokens' -exec cp {} "$dest_lib"/ \\;
            done
        """,
        mnemonic = "SetupAntlrLibPhase2",
    )

    # 4. Compile Parsers
    for parser in parsers:
        package = _get_package_name(parser)
        rel_dir = _get_output_dir_path(parser)
        
        out_dir = ctx.actions.declare_directory(ctx.label.name + "_parser_out_" + parser.basename)
        all_gen_dirs.append(out_dir)

        args = ctx.actions.args()
        args.add("-package", package)
        args.add("-visitor")
        args.add("-listener")
        # Point -lib to the directory containing tokens and grammars
        args.add("-lib", lib_phase2_dir.path)
        args.add("-o", out_dir.path + "/" + rel_dir)
        # Input file is in the phase2 dir
        args.add(lib_phase2_dir.path + "/" + parser.basename)

        ctx.actions.run(
            outputs = [out_dir],
            inputs = [lib_phase2_dir],
            executable = tool,
            arguments = [args],
            mnemonic = "AntlrParser",
            progress_message = "Compiling Parser " + parser.basename,
        )

    # 5. Package results
    out_srcjar = ctx.outputs.srcjar
    
    # Using the local jar tool from java runtime
    # We need to construct the logic carefully. We have a set of directories.
    # The 'jar' tool expects -C <dir> calls.
    
    # We will append loops to copy files to tmp_srcjar
    # Using ctx.actions.args to pass directory list
    
    package_args = ctx.actions.args()
    package_args.add(out_srcjar)
    package_args.add_all(all_gen_dirs, expand_directories = False)
    
    ctx.actions.run_shell(
        inputs = all_gen_dirs,
        outputs = [out_srcjar],
        tools = java_runtime.files, # Access to the JDK files
        arguments = [package_args],
        command = """
            jar_out="$1"
            shift
            merged_dir=$(mktemp -d)
            
            for d in "$@"; do
                if [ -d "$d" ]; then
                     cp -r "$d"/* "$merged_dir"/
                elif [ -f "$d" ]; then
                     cp "$d" "$merged_dir"/
                fi
            done
            
            # Use the jar tool from the JDK
            "{jar_tool}" cf "$jar_out" -C "$merged_dir" .
            rm -rf "$merged_dir"
        """.format(
            jar_tool = jar_tool
        ),
        mnemonic = "PackageAntlrSrcjar",
    )
    
    return [DefaultInfo(files = depset([out_srcjar]))]

antlr_gen = rule(
    implementation = _antlr_gen_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".g4"]),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
    outputs = {
        "srcjar": "%{name}.srcjar",
    },
    toolchains = ["@bazel_tools//tools/jdk:toolchain_type"],
)
