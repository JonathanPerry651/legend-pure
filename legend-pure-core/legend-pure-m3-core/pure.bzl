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

    # Build command
    # cmd = """
    #     mkdir -p {tmp_dir}
    #     {tool} {tmp_dir}/ {args}
    #     cd {tmp_dir}
    #     zip -q -r ../{output_jar} .
    # """

    # We will use a unique temp directory for this action to avoid collisions if multiple run in parallel/same sandbox?
    # Bazel sandboxing handles this, but "mkdir -p tmp" is safe enough if we name it uniquely or clean it up.
    # We'll use the rule name as part of the directory.
    tmp_dir = "gen_tmp_" + ctx.label.name

    args_str = " ".join(args_list)

    cmd = """
    set -e
    mkdir -p {tmp_dir}
    
    # Generator typically takes output dir as first arg
    {tool_path} {tmp_dir}/ {args_str}
    
    # Zip
    # We need absolute path to output or handling the cd
    # $(OUTS) in genrule is the output file path.
    # output.path gives the path.
    
    curr_dir=$(pwd)
    out_abs="$curr_dir/{output_path}"
    
    cd {tmp_dir}
    zip -q -r "$out_abs" .
    
    # Cleanup?
    cd ..
    rm -rf {tmp_dir}
    """.format(
        tmp_dir = tmp_dir,
        tool_path = tool.path,
        args_str = args_str,
        output_path = output.path,
    )

    ctx.actions.run_shell(
        inputs = srcs,
        outputs = [output],
        tools = [tool],
        command = cmd,
        mnemonic = "PureGenerator",
    )

    return [DefaultInfo(files = depset([output]))]

pure_generator = rule(
    implementation = _pure_generator_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "tool": attr.label(mandatory = True, executable = True, cfg = "exec"),
        "args_list": attr.string_list(),
        "out": attr.output(mandatory = True),
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
    # cmd = """
    #     mkdir -p $(@D)/pct-reports
    #     $(location :FunctionsGeneration) $(@D)/pct-reports org.finos.legend.pure.m3.PlatformCodeRepositoryProvider.essentialFunctions
    #     $(location :FunctionsGeneration) $(@D)/pct-reports org.finos.legend.pure.m3.PlatformCodeRepositoryProvider.grammarFunctions
    # """

    tool = ctx.executable.tool
    outputs = ctx.outputs.outs

    # We need the directory that contains the outputs.
    # Bazel rules generally should output specific files.
    # We can ask the tool to output to a specific dir.

    # We'll use the dirname of the first output.
    output_dir = outputs[0].dirname

    cmd = """
    set -e
    mkdir -p {output_dir}
    
    {tool_path} {output_dir} org.finos.legend.pure.m3.PlatformCodeRepositoryProvider.essentialFunctions
    {tool_path} {output_dir} org.finos.legend.pure.m3.PlatformCodeRepositoryProvider.grammarFunctions
    """.format(
        tool_path = tool.path,
        output_dir = output_dir,
    )

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
    },
)

def _pure_java_code_gen_impl(ctx):
    tool = ctx.executable.tool
    out_srcjar = ctx.outputs.srcjar
    repo_name = ctx.attr.repository
    srcs = ctx.files.srcs
    
    # Needs a temp dir for generation
    # Structure:
    #   work_dir/classes
    #   work_dir/target
    
    cmd = """
        set -e
        echo "DEBUG: Current Dir: $(pwd)" > debug_structure.txt
        find . -maxdepth 4 >> debug_structure.txt
        mkdir -p work_dir/classes
        mkdir -p work_dir/target
        
        {tool_path} {repo_name} work_dir/classes work_dir/target > tool_output.txt 2>&1
        
        # Zip sources
        mkdir -p src_collection
        cp debug_structure.txt src_collection/
        cp tool_output.txt src_collection/
        if [ -n "$(ls -A work_dir/target/generated-sources 2>/dev/null)" ]; then
             cp -r work_dir/target/generated-sources/* src_collection/
        fi
        if [ -n "$(ls -A work_dir/target/generated-test-sources 2>/dev/null)" ]; then
             cp -r work_dir/target/generated-test-sources/* src_collection/
        fi
        
        # Ensure we have content
        if [ -z "$(find src_collection -type f)" ]; then
             echo "No generated sources found for {repo_name}"
             exit 1
        fi

        cd src_collection
        zip -q -r ../{out_path} .
        cd ..
        rm -rf work_dir src_collection
    """.format(
        tool_path = tool.path,
        repo_name = repo_name,
        out_path = out_srcjar.path,
    )
    
    ctx.actions.run_shell(
        inputs = srcs,
        outputs = [out_srcjar],
        tools = [ctx.attr.tool[DefaultInfo].files_to_run],
        command = cmd,
        mnemonic = "PureJavaCodeGen",
    )
    
    return [DefaultInfo(files = depset([out_srcjar]))]

pure_java_code_gen = rule(
    implementation = _pure_java_code_gen_impl,
    attrs = {
        "tool": attr.label(mandatory = True, executable = True, cfg = "exec"),
        "srcs": attr.label_list(allow_files = True),
        "repository": attr.string(mandatory = True),
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
    
    cmd = """
        set -e
        mkdir -p filtered_work
        cd filtered_work
        unzip -q -o ../{src_jar_path}
        
        {rm_script}
        
        zip -q -r ../{out_jar_path} .
        cd ..
        rm -rf filtered_work
    """.format(
        src_jar_path = src_jar.path,
        out_jar_path = out_jar.path,
        rm_script = rm_script,
    )
    
    ctx.actions.run_shell(
        inputs = [src_jar],
        outputs = [out_jar],
        command = cmd,
        mnemonic = "PureJarFilter",
    )
    
    return [DefaultInfo(files = depset([out_jar]))]

pure_jar_filter = rule(
    implementation = _pure_jar_filter_impl,
    attrs = {
        "src_jar": attr.label(mandatory = True, allow_single_file = True),
        "filter_paths": attr.string_list(mandatory = True),
    },
    outputs = {
        "jar": "%{name}.srcjar", # Usually outputting a source jar
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
