genrule(
    name = "inspect_par",
    srcs = [":platform_par"],
    outs = ["inspection.txt"],
    cmd = "unzip -l $(location :platform_par) > $(OUTS)",
)
