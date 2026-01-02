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
    
    # 1. Create Lib Dir components using symlinks
    # Instead of creating a directory artifact and copying, we explicitly create symlink artifacts.
    # We will gather them and pass them to ANTLR.
    # To satisfy ANTLR's -lib <dir> requirement, we need them to be in a common directory.
    # ctx.actions.symlink can create a file at a specific path.
    
    lib_files = []
    lib_dir_path = ctx.label.name + "_lib"
    
    for f in srcs:
        # Create a symlink for each source file in the lib directory
        # e.g. <rule_name>_lib/<basename>
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
        
        # We need an output directory for this execution
        out_dir = ctx.actions.declare_directory(ctx.label.name + "_lexer_out_" + lexer.basename)
        all_gen_dirs.append(out_dir)
        
        # Using run_shell to control CWD and avoid path mirroring issues in ANTLR
        # We cd into the lib directory so ANTLR sees the grammar file as a simple filename
        
        # Construct arguments string manually or somewhat manually
        # Note: tool path must be handled relative to execroot or absolute
        
        ctx.actions.run_shell(
            inputs = lib_files,
            outputs = [out_dir],
            tools = [tool],
            command = """
                execroot=$(pwd)
                tool_path=$(realpath "{tool_path}")
                out_path="$execroot/{out_dir_path}/{rel_dir}"
                
                # cd to lib directory where symlinks are
                cd "{lib_dir_path}"
                
                # Run ANTLR
                "$tool_path" \\
                    -package {package} \\
                    -visitor -listener \\
                    -lib . \\
                    -o "$out_path" \\
                    {grammar_file}
            """.format(
                tool_path = tool.path,
                out_dir_path = out_dir.path,
                rel_dir = rel_dir,
                lib_dir_path = lib_files[0].dirname,
                package = package,
                grammar_file = lexer.basename
            ),
            mnemonic = "AntlrLexer",
            progress_message = "Compiling Lexer " + lexer.basename,
        )
        
        generated_tokens.append(out_dir)

    # 3. Update Lib with Tokens (Phase 2)
    # Put copies in lib_phase2
    
    lib_phase2_dir = ctx.actions.declare_directory(ctx.label.name + "_lib_phase2")
    
    phase2_args = ctx.actions.args()
    phase2_args.add(lib_files[0].dirname)   # Source of .g4 symlinks
    phase2_args.add(lib_phase2_dir.path)    # Dest dir
    phase2_args.add_all(generated_tokens)   # Dirs containing .tokens
    
    ctx.actions.run_shell(
        inputs = lib_files + generated_tokens,
        outputs = [lib_phase2_dir],
        arguments = [phase2_args],
        # Copy original sources and generated tokens
        command = """
            src_lib_dir="$1"
            dest_lib="$2"
            shift 2
            mkdir -p "$dest_lib"
            
            # Copy all g4 files from src lib (which are symlinks, cp follows by default for files)
            cp "$src_lib_dir"/*.g4 "$dest_lib"/
            
            # Copy tokens
            for token_dir in "$@"; do
                find "$token_dir" -name '*.tokens' -exec cp {} "$dest_lib"/ \\;
            done
        """,
        mnemonic = "SetupAntlrLibPhase2",
        use_default_shell_env = True
    )

    # 4. Compile Parsers
    for parser in parsers:
        package = _get_package_name(parser)
        rel_dir = _get_output_dir_path(parser)
        
        out_dir = ctx.actions.declare_directory(ctx.label.name + "_parser_out_" + parser.basename)
        all_gen_dirs.append(out_dir)

        ctx.actions.run_shell(
            inputs = [lib_phase2_dir],
            outputs = [out_dir],
            tools = [tool],
            command = """
                execroot=$(pwd)
                tool_path=$(realpath "{tool_path}")
                out_path="$execroot/{out_dir_path}/{rel_dir}"
                
                cd "{lib_dir_path}"
                
                "$tool_path" \\
                    -package {package} \\
                    -visitor -listener \\
                    -lib . \\
                    -o "$out_path" \\
                    {grammar_file}
            """.format(
                tool_path = tool.path,
                out_dir_path = out_dir.path,
                rel_dir = rel_dir,
                lib_dir_path = lib_phase2_dir.path,
                package = package,
                grammar_file = parser.basename
            ),
            mnemonic = "AntlrParser",
            progress_message = "Compiling Parser " + parser.basename,
        )

    # 5. Package results
    out_jar = ctx.outputs.srcjar
    
    package_args = ctx.actions.args()
    package_args.add(out_jar.path)
    # Important: Do not expand directories, we want the directory paths themselves
    package_args.add_all(all_gen_dirs, expand_directories = False)
    
    ctx.actions.run_shell(
        inputs = all_gen_dirs,
        outputs = [out_jar],
        arguments = [package_args],
        command = """
            jar_out="$1"
            shift
            merged_dir=$(mktemp -d)
            
            for d in "$@"; do
                if [ -d "$d" ]; then
                     cp -r "$d"/* "$merged_dir"/
                elif [ -f "$d" ]; then
                     # If generic file input (though we expect directories from lexer/parser)
                     cp "$d" "$merged_dir"/
                fi
            done
            
            jar cf "$jar_out" -C "$merged_dir" .
            rm -rf "$merged_dir"
        """,
        mnemonic = "PackageAntlrSrcjar",
        use_default_shell_env = True
    )
    
    return [DefaultInfo(files = depset([out_jar]))]

antlr_gen = rule(
    implementation = _antlr_gen_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".g4"]),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
    },
    outputs = {
        "srcjar": "%{name}.srcjar",
    },
)
