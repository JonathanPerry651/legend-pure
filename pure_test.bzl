load("@rules_java//java:defs.bzl", "java_library", "java_test")

def _gen_compiled_test_impl(ctx):
    out = ctx.actions.declare_file(ctx.attr.out)

    # Use the first source file
    if not ctx.files.srcs:
        fail("No source files provided")
    src = ctx.files.srcs[0]

    args = ctx.actions.args()
    args.add(src.path)
    args.add(out.path)
    if ctx.attr.include_verifiers:
        args.add("true")
    else:
        args.add("false")

    ctx.actions.run(
        outputs = [out],
        inputs = [src],
        executable = ctx.executable.tool,
        arguments = [args],
        progress_message = "Generating compiled test source %s" % out.short_path,
    )
    return [DefaultInfo(files = depset([out]))]

_gen_compiled_test_src = rule(
    implementation = _gen_compiled_test_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True, mandatory = True),
        "out": attr.string(mandatory = True),
        "include_verifiers": attr.bool(default = False),
        "tool": attr.label(executable = True, cfg = "exec", default = "//tools/compiled-test-generator:CompiledTestGenerator"),
    },
)

def _pure_test_impl(name, srcs, deps = [], include_verifiers = False, compiled_test_deps = [], test_class = None, visibility = None, tags = []):
    # 1. Base Library (Interpreted Test Source)
    lib_name = name + "_lib"

    java_library(
        name = lib_name,
        srcs = srcs,
        deps = deps,
        visibility = visibility,
        exports = deps,
        tags = tags,
    )

    # 2. Interpreted Test
    java_test(
        name = name,
        test_class = test_class,
        runtime_deps = [":" + lib_name],
        tags = tags,
        size = "medium",
        jvm_flags = ["-Xmx1G"],
    )

    # 3. Compiled Test Generation
    compiled_test_target_name = name + "_Compiled"
    compiled_test_class_name = name + "Compiled"
    compiled_test_file_name = compiled_test_class_name + ".java"

    _gen_compiled_test_src(
        name = compiled_test_target_name + "_gen",
        srcs = srcs,
        out = compiled_test_file_name,
        include_verifiers = include_verifiers,
        tags = tags,
    )

    # 4. Compiled Test
    java_test(
        name = compiled_test_target_name,
        srcs = [":" + compiled_test_target_name + "_gen"],
        test_class = test_class + "Compiled" if test_class else None,
        deps = [
            ":" + lib_name,
            "//legend-pure/legend-pure-runtime/legend-pure-runtime-java-engine-compiled:legend-pure-runtime-java-engine-compiled",
            "//legend-pure/legend-pure-runtime/legend-pure-runtime-java-engine-compiled:platform_metadata",
            "//legend-pure/legend-pure-runtime/legend-pure-runtime-java-engine-compiled/src/test/java/org/finos/legend/pure/runtime/java/compiled/runtime:CompiledClassloaderStateVerifier_lib",
            "//legend-pure/legend-pure-runtime/legend-pure-runtime-java-engine-compiled/src/test/java/org/finos/legend/pure/runtime/java/compiled/runtime:CompiledMetadataStateVerifier_lib",
            "//legend-pure/legend-pure-runtime/legend-pure-runtime-java-engine-compiled/src/test/java/org/finos/legend/pure/runtime/java/compiled/runtime:TestIdBuilder_lib",
        ] + compiled_test_deps,
        tags = tags,
        size = "large",
        jvm_flags = ["-Xmx2G"],
    )

pure_test = macro(
    implementation = _pure_test_impl,
    attrs = {
        "srcs": attr.label_list(mandatory = True, allow_files = True, configurable = False),
        "deps": attr.label_list(default = [], configurable = False),
        "include_verifiers": attr.bool(default = False, configurable = False),
        "compiled_test_deps": attr.label_list(default = [], configurable = False),
        "test_class": attr.string(configurable = False),
        "tags": attr.string_list(configurable = False),
    },
)
