def parse_platform(platform):
    os, arch = platform.split("_")
    return struct(arch = arch, os = os)

PLATFORMS = [
    parse_platform(platform)
    for platform in ["darwin_amd64", "darwin_arm64", "freebsd_386", "linux_amd64", "linux_arm64", "windows_386", "windows_amd"]
]

def cpu_constraints(arch):
    if arch == "386":
        return {"i386": "@platforms//cpu:i386"}
    if arch == "arm64":
        return {"aarch64": "@platforms//cpu:aarch64"}
    if arch == "amd64":
        return {"amd64": "@platforms//cpu:x86_64"}
    return {}

def os_constraints(os):
    if os == "linux":
        return {"linux": "@platforms//os:linux"}
    if os == "darwin":
        return {"macos": "@platforms//os:macos"}
    if os == "windows":
        return {"windows": "@platforms//os:windows"}
    return {}
