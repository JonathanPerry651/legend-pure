load("//tools:zip_tree_artifacts.bzl", "zip_tree_artifacts")
load("@rules_java//java:defs.bzl", "java_common")

def _pure_antlr_gen_impl(ctx):
    # Create the antlr_flat output directory structure within bazel-out
    # We can't really "mkdir" in a rule in the same way, we define outputs.
    # But for ANTLR generation that expects a flat directory or specific structure,
    # we simulate the shell logic.

    # Outputs
    outputs = ctx.outputs.outs

    # Tools
    antlr_tool = ctx.executable.tool

    # Source files
    srcs = ctx.files.srcs
    grammar_files_dep = ctx.files.grammar_files

    # Combine all sources
    all_grammar_files = srcs + grammar_files_dep

    # We need to construct a command that mimics the complex logic of the original genrule
    # 1. Create a flattened directory
    # 2. Copy all grammars there
    # 3. Run ANTLR tool for each specific grammar file
    # 4. Move outputs to the correct package structure in the output tree

    # The command string
    cmd = """
    set -e
    mkdir -p antlr_flat
    
    # Copy all sources (m3 and m4) to antlr_flat
    # We use a loop to handle the list of files
    """

    # We need to pass the paths of files.
    # Since we are in a rule, we can access file paths.

    # Resolving files to copy.
    # Note: ctx.files hierarchy might be complex, so we just iterate and cp
    copy_cmds = []
    for f in all_grammar_files:
        copy_cmds.append("cp \"{src}\" antlr_flat/".format(src = f.path))

    cmd += "\n".join(copy_cmds)

    # Helper function to generate ANTLR command for a specific file
    def gen_antlr_cmd(grammar_name, package, output_dir_segment):
        # The original script does:
        # $(location //legend-pure:antlr4_tool) -package ... -visitor -listener -lib antlr_flat -o ... antlr_flat/File.g4
        # Then moves outputs from .../antlr_flat/ to .../

        # We need the output dir relative to the bin dir
        # ctx.bin_dir.path is the root of bazel-out/.../bin
        # We want the output to be in the package directory of the rule

        # In the genrule $(RULEDIR) expands to the directory of the BUILD file in output tree.
        # Here we don't have $(RULEDIR). We assume the outputs are declared in the providers.
        # But we need to define where ANTLR writes to.

        # Ideally we write to a temp dir and then copy to declared outputs?
        # Or we tell ANTLR to write to the right place.

        # Let's map the logic:
        # -o $(RULEDIR)/org/finos/legend/pure/m3/serialization/grammar/m3parser/antlr
        # This path is relative to the execution root.

        # Construct the target output dir for this grammar
        target_out_dir = ctx.bin_dir.path + "/" + ctx.label.package + "/" + output_dir_segment

        # The command:
        return """
        # {grammar_name}
        {tool} \\
        -package {package} \\
        -visitor -listener \\
        -lib antlr_flat \\
        -o {target_out_dir} \\
        antlr_flat/{grammar_name}
        
        # Move up logic from the bash script. 
        # The script does: mv .../antlr_flat/* .../
        # This implies ANTLR with -lib antlr_flat might be creating a subdirectory 'antlr_flat' in the output?
        # Or it might be because the input file is antlr_flat/M3Lexer.g4? 
        # Yes, ANTLR 4 often mirrors input dir structure in output.
        
        if [ -d "{target_out_dir}/antlr_flat" ]; then
            mv {target_out_dir}/antlr_flat/* {target_out_dir}/
            rmdir {target_out_dir}/antlr_flat
        fi
        """.format(
            grammar_name = grammar_name,
            package = package,
            tool = antlr_tool.path,
            target_out_dir = target_out_dir,
        )

    # 1. Lexers
    cmd += gen_antlr_cmd("M3Lexer.g4", "org.finos.legend.pure.m3.serialization.grammar.m3parser.antlr", "org/finos/legend/pure/m3/serialization/grammar/m3parser/antlr")
    cmd += gen_antlr_cmd("TopAntlrLexer.g4", "org.finos.legend.pure.m3.serialization.grammar.top.antlr", "org/finos/legend/pure/m3/serialization/grammar/top/antlr")

    # 2. Copy generated tokens to antlr_flat
    cmd += """
    # Copy generated tokens dependent logic
    # We need to find where M3Lexer.tokens and TopAntlrLexer.tokens were generated.
    # They should be in their respective output dirs.
    
    cp {bin_dir}/{pkg}/org/finos/legend/pure/m3/serialization/grammar/m3parser/antlr/M3Lexer.tokens antlr_flat/
    cp {bin_dir}/{pkg}/org/finos/legend/pure/m3/serialization/grammar/top/antlr/TopAntlrLexer.tokens antlr_flat/
    """.format(bin_dir = ctx.bin_dir.path, pkg = ctx.label.package)

    # 3. Parsers
    cmd += gen_antlr_cmd("M3Parser.g4", "org.finos.legend.pure.m3.serialization.grammar.m3parser.antlr", "org/finos/legend/pure/m3/serialization/grammar/m3parser/antlr")
    cmd += gen_antlr_cmd("TopAntlrParser.g4", "org.finos.legend.pure.m3.serialization.grammar.top.antlr", "org/finos/legend/pure/m3/serialization/grammar/top/antlr")

    # 4. TreePath
    cmd += gen_antlr_cmd("TreePath.g4", "org.finos.legend.pure.m3.serialization.grammar.treepathparser", "org/finos/legend/pure/m3/serialization/grammar/treepathparser")

    # Cleanup
    cmd += "\nrm -rf antlr_flat"

    ctx.actions.run_shell(
        inputs = all_grammar_files,
        outputs = outputs,
        tools = [antlr_tool],
        command = cmd,
        mnemonic = "PureAntlrGen",
    )

    return [DefaultInfo(files = depset(outputs))]

pure_antlr_gen = rule(
    implementation = _pure_antlr_gen_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "grammar_files": attr.label_list(allow_files = True),
        "outs": attr.output_list(),
        "tool": attr.label(default = Label("//legend-pure:antlr4_tool"), executable = True, cfg = "exec"),
    },
)

def _pure_generator_impl(ctx):
    # Inputs
    srcs = ctx.files.srcs
    tool = ctx.executable.tool
    output = ctx.outputs.out

    # Arguments
    args_list = ctx.attr.args_list

    # Output directory for the generator
    gen_dir = ctx.actions.declare_directory(ctx.label.name + "_gen")

    # Action 1: Run generator
    # We'll use a wrapper shell if needed, but the generator usually takes a dir.
    # Note: Generator needs to write to gen_dir.
    gen_args = ctx.actions.args()
    # Fix: Append / to ensure the generator treats it as a directory prefix correctly
    gen_args.add(gen_dir.path + "/") 
    gen_args.add_all(args_list)

    ctx.actions.run(
        outputs = [gen_dir],
        inputs = srcs,
        executable = tool,
        arguments = [gen_args],
        mnemonic = "PureGeneratorRun",
    )

    # Action 2: Zip with zipper
    zip_tree_artifacts(
        ctx,
        output = output,
        inputs = [gen_dir],
        java_runtime_target = ctx.attr._jdk,
    )

    return [DefaultInfo(files = depset([output]))]

pure_generator = rule(
    implementation = _pure_generator_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "tool": attr.label(mandatory = True, executable = True, cfg = "exec"),
        "args_list": attr.string_list(),
        "out": attr.output(mandatory = True),
        "_jdk": attr.label(
            default = Label("@bazel_tools//tools/jdk:current_java_runtime"),
            providers = [java_common.JavaRuntimeInfo],
        ),
    },
)

PURE_PLATFORM_VERSION = "0.0.0-SNAPSHOT"

def _pure_par_impl(ctx):
    # Used for platform_par
    # cmd = "$(location :PureJarGenerator) 0.0.0-SNAPSHOT platform $(@D)"

    tool = ctx.executable.tool
    output = ctx.outputs.out
    version = ctx.attr.version
    repo_name = ctx.attr.repo_name

    # We need to handle generation into $(@D) which mimics genrule behavior.
    # PureJarGenerator takes (version, repoName, outputDir)
    # It generates "pure-[repoName].par" in outputDir.

    # Since our rule declares the output file explicitly, we should tell the generator
    # to generate it there, or generate to a temp dir and move it.
    
    # We construct the expected generated filename based on repo_name
    expected_par_name = "pure-{}.par".format(repo_name)

    cmd = """
    set -e
    # Create a temp dir
    mkdir -p par_tmp_comp
    
    {tool_path} {version} {repo_name} par_tmp_comp
    
    # Move the expected result file to the declared output path
    # Expected: pure-{repo_name}.par
    mv par_tmp_comp/{expected_par_name} {output_path}
    
    rm -rf par_tmp_comp
    """.format(
        tool_path = tool.path,
        output_path = output.path,
        version = version,
        repo_name = repo_name,
        expected_par_name = expected_par_name,
    )

    ctx.actions.run_shell(
        inputs = [],  # No source inputs for this one? It reads embedded resources?
        outputs = [output],
        tools = [tool],
        command = cmd,
        mnemonic = "PureParGen",
    )

    return [DefaultInfo(files = depset([output]))]

pure_par = rule(
    implementation = _pure_par_impl,
    attrs = {
        "tool": attr.label(mandatory = True, executable = True, cfg = "exec"),
        "out": attr.output(mandatory = True),
        "version": attr.string(default = PURE_PLATFORM_VERSION),
        "repo_name": attr.string(mandatory = True),
    },
)

def _pure_report_impl(ctx):
    tool = ctx.executable.tool
    outputs = ctx.outputs.outs
    report_classes = ctx.attr.report_classes

    # Determine output directory from the first output
    # All outputs must be in the same directory for this tool logic
    output_dir = outputs[0].dirname

    cmd_lines = ["set -e", "mkdir -p {output_dir}".format(output_dir = output_dir)]
    
    for cls in report_classes:
        cmd_lines.append("{tool_path} {output_dir} {cls}".format(
            tool_path = tool.path,
            output_dir = output_dir,
            cls = cls
        ))
    
    cmd = "\n".join(cmd_lines)

    ctx.actions.run_shell(
        inputs = [],
        outputs = outputs,
        tools = [tool],
        command = cmd,
        mnemonic = "PurePctReport",
    )

    return [DefaultInfo(files = depset(outputs))]

pure_pct_report = rule(
    implementation = _pure_report_impl,
    attrs = {
        "tool": attr.label(mandatory = True, executable = True, cfg = "exec"),
        "outs": attr.output_list(mandatory = True),
        "report_classes": attr.string_list(mandatory = True),
    },
)

def _pure_java_code_gen_impl(ctx):
    tool = ctx.executable.tool
    out_srcjar = ctx.outputs.srcjar
    repo_name = ctx.attr.repository
    srcs = ctx.files.srcs
    exclusions = ctx.attr.exclusions
    
    # Output directories for the generator
    classes_dir = ctx.actions.declare_directory(ctx.label.name + "_classes")
    target_dir = ctx.actions.declare_directory(ctx.label.name + "_target")

    # Action 1: Run generator
    # Generator takes: <repo> <classesDir> <targetDir>
    gen_args = ctx.actions.args()
    gen_args.add(repo_name)
    gen_args.add(classes_dir.path)
    gen_args.add(target_dir.path)

    tool_output = ctx.actions.declare_file(ctx.label.name + "_tool_output.txt")

    ctx.actions.run_shell(
        outputs = [classes_dir, target_dir, tool_output],
        inputs = srcs,
        tools = [tool],
        command = "{tool_path} $1 $2 $3 > {out} 2>&1".format(
            tool_path = tool.path,
            out = tool_output.path,
        ),
        arguments = [gen_args],
        mnemonic = "PureJavaCodeGenRun",
    )
    
    # Handling Metadata (Optional)
    outputs = [out_srcjar]
    if ctx.outputs.metadata_jar:
        # We need to extract metadata from classes_dir/metadata and zip it
        # We'll create a new directory solely for metadata to zip
        metadata_zip_dir = ctx.actions.declare_directory(ctx.label.name + "_metadata_zip_root")
        
        ctx.actions.run_shell(
             inputs = [classes_dir],
             outputs = [metadata_zip_dir],
             command = """
                 mkdir -p {meta_root}
                 if [ -d "{classes}/metadata" ]; then
                     cp -r "{classes}/metadata" {meta_root}/
                 fi
             """.format(
                 meta_root = metadata_zip_dir.path,
                 classes = classes_dir.path,
             ),
             mnemonic = "PureJavaCodeGenMeta",
        )
        
        zip_tree_artifacts(
            ctx,
            output = ctx.outputs.metadata_jar,
            inputs = [metadata_zip_dir],
            java_runtime_target = ctx.attr._jdk,
        )
        outputs.append(ctx.outputs.metadata_jar)

    # Action 2: Merge for zipping
    merged_dir = ctx.actions.declare_directory(ctx.label.name + "_merged")
    
    # Construct exclusion commands
    rm_cmds = []
    for excl in exclusions:
         rm_cmds.append("rm -rf \"{merged}/{excl}\"".format(merged = merged_dir.path, excl = excl))
    cleanup_script = "\n".join(rm_cmds)

    merge_args = ctx.actions.args()
    merge_args.add(target_dir.path)
    merge_args.add(tool_output.path)
    merge_args.add(merged_dir.path)
    
    ctx.actions.run_shell(
         inputs = [target_dir, tool_output],
         outputs = [merged_dir],
         arguments = [merge_args],
         command = """
             set -e
             src_dir="$1"
             tool_out="$2"
             dest_dir="$3"
             
             # Copy tool output
             cp "$tool_out" "$dest_dir/"
             
             # Merge generated sources
             # We use cp -r src/. dest/ to merge contents
             if [ -d "$src_dir/generated-sources" ]; then
                 cp -r "$src_dir/generated-sources"/. "$dest_dir/"
             fi
             
             if [ -d "$src_dir/generated-test-sources" ]; then
                 cp -r "$src_dir/generated-test-sources"/. "$dest_dir/"
             fi
             
             # Apply exclusions
             {cleanup}
         """.format(cleanup = cleanup_script),
         mnemonic = "PureJavaCodeGenMerge",
    )

    # Action 3: Zip with zipper
    zip_tree_artifacts(
        ctx,
        output = out_srcjar,
        inputs = [merged_dir],
        java_runtime_target = ctx.attr._jdk,
    )
    
    return [DefaultInfo(files = depset(outputs))]

pure_java_code_gen = rule(
    implementation = _pure_java_code_gen_impl,
    attrs = {
        "tool": attr.label(mandatory = True, executable = True, cfg = "exec"),
        "srcs": attr.label_list(allow_files = True),
        "repository": attr.string(mandatory = True),
        "exclusions": attr.string_list(default = []),
        "metadata_jar": attr.output(),
        "_jdk": attr.label(
            default = Label("@bazel_tools//tools/jdk:current_java_runtime"),
            providers = [java_common.JavaRuntimeInfo],
        ),
    },
    outputs = {
        "srcjar": "%{name}.srcjar",
    },
)

def _pure_jar_filter_impl(ctx):
    src_jar = ctx.file.src_jar
    out_jar = ctx.outputs.jar
    filter_paths = ctx.attr.filter_paths
    
    # Construct rm command
    rm_cmds = []
    for p in filter_paths:
        rm_cmds.append("rm -rf " + p)
    rm_script = "\n".join(rm_cmds)
    
    # Discovery of jar tool for extraction
    jar_tool = None
    for f in ctx.attr._jar[java_common.JavaRuntimeInfo].files.to_list():
        if f.basename == "jar":
            jar_tool = f
            break
    if not jar_tool:
        fail("jar tool not found in java_runtime")

    # Output directory for the filtered content
    filtered_dir = ctx.actions.declare_directory(ctx.label.name + "_filtered")

    args = ctx.actions.args()
    args.add(jar_tool)
    args.add(src_jar)
    args.add(filtered_dir.path)

    ctx.actions.run_shell(
        inputs = [src_jar],
        outputs = [filtered_dir],
        tools = [jar_tool],
        arguments = [args],
        command = """
            set -e
            jar_tool="$1"
            src="$2"
            dest="$3"
            
            src_abs="$(pwd)/$src"
            
            cd "$dest"
            "$jar_tool" xf "$src_abs"
            {rm_script}
            
            # Verification: Check if empty? zip_tree_artifacts handles empty dirs by producing empty zip or we might want to fail?
            # pure_jar_filter usually expects content.
        """.format(rm_script = rm_script),
        mnemonic = "PureJarFilterExtract",
    )
    
    zip_tree_artifacts(
        ctx,
        output = out_jar,
        inputs = [filtered_dir],
        java_runtime_target = ctx.attr._jdk,
    )
    
    return [DefaultInfo(files = depset([out_jar]))]

pure_jar_filter = rule(
    implementation = _pure_jar_filter_impl,
    attrs = {
        "src_jar": attr.label(mandatory = True, allow_single_file = True),
        "filter_paths": attr.string_list(mandatory = True),
        "_jdk": attr.label(
            default = Label("@bazel_tools//tools/jdk:current_java_runtime"),
            providers = [java_common.JavaRuntimeInfo],
        ),
        "_jar": attr.label(
            default = Label("@bazel_tools//tools/jdk:current_java_runtime"),
            providers = [java_common.JavaRuntimeInfo],
        ),
    },
    outputs = {
        "jar": "%{name}.srcjar",
    },
)

def _pure_resource_copy_impl(ctx):
    src = ctx.file.src
    output = ctx.outputs.out
    
    # Just a simple copy
    ctx.actions.run_shell(
        inputs = [src],
        outputs = [output],
        command = "cp \"{src}\" \"{out}\"".format(src = src.path, out = output.path),
        mnemonic = "PureResourceCopy",
    )
    
    return [DefaultInfo(files = depset([output]))]

pure_resource_copy = rule(
    implementation = _pure_resource_copy_impl,
    attrs = {
        "src": attr.label(mandatory = True, allow_single_file = True),
        "out": attr.output(mandatory = True),
    },
)

def _pure_jar_extract_impl(ctx):
    src_jar = ctx.file.src_jar
    out_jar = ctx.outputs.jar
    # Patterns to keep
    include_patterns = ctx.attr.include_patterns
    
    # Discovery of jar tool for extraction
    jar_tool = None
    for f in ctx.attr._jar[java_common.JavaRuntimeInfo].files.to_list():
        if f.basename == "jar":
            jar_tool = f
            break
    if not jar_tool:
        fail("jar tool not found in java_runtime")

    extract_dir = ctx.actions.declare_directory(ctx.label.name + "_extracted")
    filtered_dir = ctx.actions.declare_directory(ctx.label.name + "_filtered")
    
    # Script to extract and filter
    script = """
import os
import sys
import fnmatch
import shutil
import subprocess

src_jar = sys.argv[1]
extract_root = sys.argv[2]
filtered_root = sys.argv[3]
jar_tool = sys.argv[4]
patterns = sys.argv[5:]

# 1. Extract
os.makedirs(extract_root, exist_ok=True)
# We use absolute path for jar and tool to be safe when cwd changes
src_jar = os.path.abspath(src_jar)
jar_tool = os.path.abspath(jar_tool)

subprocess.check_call([jar_tool, "xf", src_jar], cwd=extract_root)

# 2. Filter
os.makedirs(filtered_root, exist_ok=True)

# Walk and match
for root, dirs, files in os.walk(extract_root):
    for f in files:
        full_path = os.path.join(root, f)
        rel_path = os.path.relpath(full_path, extract_root)
        
        keep = False
        for p in patterns:
            # Match against the relative path
            if fnmatch.fnmatch(rel_path, p):
                keep = True
                break
        
        if keep:
            dest_path = os.path.join(filtered_root, rel_path)
            os.makedirs(os.path.dirname(dest_path), exist_ok=True)
            shutil.copy2(full_path, dest_path)
"""

    # Write script to file
    script_file = ctx.actions.declare_file(ctx.label.name + "_filter.py")
    ctx.actions.write(script_file, script)

    ctx.actions.run(
        inputs = [src_jar, script_file],
        outputs = [extract_dir, filtered_dir],
        tools = [jar_tool],
        executable = "python3",
        arguments = [script_file.path, src_jar.path, extract_dir.path, filtered_dir.path, jar_tool.path] + include_patterns,
        mnemonic = "PureJarExtract",
        use_default_shell_env = True,
    )
    
    # 3. Zip
    zip_tree_artifacts(
        ctx,
        output = out_jar,
        inputs = [filtered_dir],
        java_runtime_target = ctx.attr._jdk,
    )
    
    return [DefaultInfo(files = depset([out_jar]))]

pure_jar_extract = rule(
    implementation = _pure_jar_extract_impl,
    attrs = {
        "src_jar": attr.label(mandatory = True, allow_single_file = True),
        "include_patterns": attr.string_list(mandatory = True),
        "_jdk": attr.label(default = Label("@bazel_tools//tools/jdk:current_java_runtime"), providers = [java_common.JavaRuntimeInfo]),
        "_jar": attr.label(default = Label("@bazel_tools//tools/jdk:current_java_runtime"), providers = [java_common.JavaRuntimeInfo]),
    },
    outputs = {"jar": "%{name}.srcjar"},
)
