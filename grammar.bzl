load("@rules_java//java:defs.bzl", "java_common")
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

    # 1. Create Lib Dir as a Tree Artifact
    lib_dir = ctx.actions.declare_directory(ctx.label.name + "_lib")
    
    # We need to structure the lib dir. 
    # Since we can't easily symlink a list of files into a directory artifact in Starlark without a custom action:
    pkg_struct_args = ctx.actions.args()
    pkg_struct_args.add_all([lib_dir], expand_directories = False)
    pkg_struct_args.add_all(srcs)
    
    ctx.actions.run_shell(
        outputs = [lib_dir],
        inputs = srcs,
        command = """
            set -e
            out_dir="$1"
            shift
            mkdir -p "$out_dir"
            for f in "$@"; do
                cp "$f" "$out_dir/"
            done
        """,
        arguments = [pkg_struct_args],
        mnemonic = "SetupAntlrLib",
        execution_requirements = {"supports-path-mapping": "1"},
    )
    
    # Filter sources (we still need to know which is which, but we use the original srcs list for filtering)
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
        args.add(tool)
        args.add_all([out_dir], expand_directories = False)
        args.add(rel_dir)
        args.add_all([lib_dir], expand_directories = False)
        args.add(lexer.basename)
        args.add(package)
        
        ctx.actions.run_shell(
            outputs = [out_dir],
            inputs = [lib_dir, lexer], # lexer is still needed individually? Or should we find it in lib_dir? 
            # We can pass lexer as input so Bazel knows, but tool command uses lib_dir for -lib. 
            # The grammar file itself is passed as argument "$grammar_base", which is just filename.
            # ANTLR looks for it in "." (current dir) or -lib path? 
            # Script does `cd "$grammar_dir"`. 
            # We need to adjust script to use lib_dir.
            tools = [tool],
            command = """
                set -e
                tool_path="$1"
                out_root_path="$2"
                rel_dir="$3"
                grammar_dir="$4"
                grammar_base="$5"
                package="$6"
                
                # Resolve absolute paths before changing directory
                if [[ "$tool_path" != /* ]]; then tool_path="$(pwd)/$tool_path"; fi
                if [[ "$out_root_path" != /* ]]; then out_root_path="$(pwd)/$out_root_path"; fi
                if [[ "$grammar_dir" != /* ]]; then grammar_dir="$(pwd)/$grammar_dir"; fi
                
                out_dir_abs="$out_root_path/$rel_dir"
                mkdir -p "$out_dir_abs"
                
                cd "$grammar_dir"
                "$tool_path" -o "$out_dir_abs" -package "$package" -visitor -listener -lib . "$grammar_base"
                
                if [ -z "$(find "$out_root_path" -type f)" ]; then
                    echo "ERROR: ANTLR Lexer produced no files in $out_root_path"
                    exit 1
                fi
            """,
            arguments = [args],
            mnemonic = "AntlrLexer",
            progress_message = "Generating ANTLR lexer for %s" % lexer.short_path,
            execution_requirements = {"supports-path-mapping": "1"},
        )

        generated_tokens.append(out_dir)

    # 3. Update Lib with Tokens (Phase 2)
    lib_phase2_dir = ctx.actions.declare_directory(ctx.label.name + "_lib_phase2")

    args_phase2 = ctx.actions.args()
    args_phase2.add_all([lib_phase2_dir], expand_directories = False)
    args_phase2.add_all([lib_dir], expand_directories = False)
    args_phase2.add_all(generated_tokens)

    ctx.actions.run_shell(
        inputs = [lib_dir] + generated_tokens,
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
        arguments = [args_phase2],
        mnemonic = "SetupAntlrLibPhase2",
        execution_requirements = {"supports-path-mapping": "1"},
    )

    # 4. Compile Parsers
    for parser in parsers:
        package = _get_package_name(parser)
        rel_dir = _get_output_dir_path(parser)

        out_dir = ctx.actions.declare_directory(ctx.label.name + "_parser_out_" + parser.basename)
        all_gen_dirs.append(out_dir)

        args_parser = ctx.actions.args()
        args_parser.add(tool)
        args_parser.add_all([out_dir], expand_directories = False)
        args_parser.add(rel_dir)
        args_parser.add_all([lib_phase2_dir], expand_directories = False)
        args_parser.add_all([lib_phase2_dir], expand_directories = False) # grammar_dir
        args_parser.add(parser.basename)
        args_parser.add(package)
        
        ctx.actions.run_shell(
            outputs = [out_dir],
            inputs = [lib_phase2_dir],
            tools = [tool],
            command = """
                set -e
                tool_path="$1"
                out_root_path="$2"
                rel_dir="$3"
                lib_phase2_path="$4"
                grammar_dir="$5"
                grammar_base="$6"
                package="$7"
                
                # Resolve absolute paths
                if [[ "$tool_path" != /* ]]; then tool_path="$(pwd)/$tool_path"; fi
                if [[ "$out_root_path" != /* ]]; then out_root_path="$(pwd)/$out_root_path"; fi
                if [[ "$lib_phase2_path" != /* ]]; then lib_phase2_path="$(pwd)/$lib_phase2_path"; fi
                if [[ "$grammar_dir" != /* ]]; then grammar_dir="$(pwd)/$grammar_dir"; fi
                
                out_dir_abs="$out_root_path/$rel_dir"
                mkdir -p "$out_dir_abs"
                
                cd "$grammar_dir"
                # -lib expects the directory containing tokens. 
                "$tool_path" -o "$out_dir_abs" -package "$package" -visitor -listener -lib "$lib_phase2_path" "$grammar_base"
                
                if [ -z "$(find "$out_root_path" -type f)" ]; then
                    echo "ERROR: ANTLR Parser produced no files in $out_root_path"
                    exit 1
                fi
            """,
            arguments = [args_parser],
            mnemonic = "AntlrParser",
            progress_message = "Generating ANTLR parser for %s" % parser.short_path,
            execution_requirements = {"supports-path-mapping": "1"},
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
