load("@rules_java//java:defs.bzl", "java_binary", "java_common")
load("//tools:zip_tree_artifacts.bzl", "zip_tree_artifacts")

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
        
        ctx.actions.run_shell(
            outputs = [out_dir],
            inputs = lib_files + [lexer],
            tools = [tool],
            command = """
                set -e
                tool_abs="$(pwd)/$1"
                out_root_abs="$(pwd)/$2"
                rel_dir="$3"
                grammar_dir="$4"
                grammar_base="$5"
                package="$6"
                
                out_dir_abs="$out_root_abs/$rel_dir"
                mkdir -p "$out_dir_abs"
                
                cd "$grammar_dir"
                "$tool_abs" -o "$out_dir_abs" -package "$package" -visitor -listener -lib . "$grammar_base"
                
                if [ -z "$(find "$out_root_abs" -type f)" ]; then
                    echo "ERROR: ANTLR Lexer produced no files in $out_root_abs"
                    exit 1
                fi
            """,
            arguments = [tool.path, out_dir.path, rel_dir, lib_files[0].dirname, lexer.basename, package],
            mnemonic = "AntlrLexer",
            progress_message = "Generating ANTLR lexer for %s" % lexer.short_path,
        )
        
        generated_tokens.append(out_dir)

    # 3. Update Lib with Tokens (Phase 2)
    lib_phase2_dir = ctx.actions.declare_directory(ctx.label.name + "_lib_phase2")
    
    ctx.actions.run_shell(
        inputs = lib_files + generated_tokens,
        outputs = [lib_phase2_dir],
        command = """
            set -e
            dest_lib="$1"
            src_lib_dir="$2"
            shift 2
            
            mkdir -p "$dest_lib"
            cp "$src_lib_dir"/*.g4 "$dest_lib"/
            for token_dir in "$@"; do
                find "$token_dir" -name '*.tokens' -exec cp {} "$dest_lib"/ \\;
            done
        """,
        arguments = [lib_phase2_dir.path, lib_files[0].dirname] + [d.path for d in generated_tokens],
        mnemonic = "SetupAntlrLibPhase2",
    )

    # 4. Compile Parsers
    for parser in parsers:
        package = _get_package_name(parser)
        rel_dir = _get_output_dir_path(parser)
        
        out_dir = ctx.actions.declare_directory(ctx.label.name + "_parser_out_" + parser.basename)
        all_gen_dirs.append(out_dir)

        ctx.actions.run_shell(
            outputs = [out_dir],
            inputs = [lib_phase2_dir],
            tools = [tool],
            command = """
                set -e
                tool_abs="$(pwd)/$1"
                out_root_abs="$(pwd)/$2"
                rel_dir="$3"
                lib_phase2_abs="$(pwd)/$4"
                grammar_dir="$5"
                grammar_base="$6"
                package="$7"
                
                out_dir_abs="$out_root_abs/$rel_dir"
                mkdir -p "$out_dir_abs"
                
                cd "$grammar_dir"
                "$tool_abs" -o "$out_dir_abs" -package "$package" -visitor -listener -lib "$lib_phase2_abs" "$grammar_base"
                
                if [ -z "$(find "$out_root_abs" -type f)" ]; then
                    echo "ERROR: ANTLR Parser produced no files in $out_root_abs"
                    exit 1
                fi
            """,
            arguments = [tool.path, out_dir.path, rel_dir, lib_phase2_dir.path, lib_phase2_dir.path, parser.basename, package],
            mnemonic = "AntlrParser",
            progress_message = "Generating ANTLR parser for %s" % parser.short_path,
        )

    # 5. Package results
    out_srcjar = ctx.outputs.srcjar
    
    zip_tree_artifacts(
        ctx,
        output = out_srcjar,
        inputs = all_gen_dirs,
        java_runtime_target = ctx.attr._jdk,
    )
    
    return [DefaultInfo(files = depset([out_srcjar]))]

antlr_gen = rule(
    implementation = _antlr_gen_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".g4"]),
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
        "_jdk": attr.label(
            default = Label("@bazel_tools//tools/jdk:current_java_runtime"),
            providers = [java_common.JavaRuntimeInfo],
        ),
    },
    outputs = {
        "srcjar": "%{name}.srcjar",
    },
)
