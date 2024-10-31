const std = @import("std");
const builtin = @import("builtin");
const Build = std.Build;

const log = std.log.scoped(.spirv_cross_zig);


pub fn build(b: *Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const debug = b.option(bool, "debug", "Whether to produce detailed debug symbols (g0) or not. These increase binary size considerably.") orelse false;
    const shared = b.option(bool, "shared", "Build spirv-tools as a shared library") orelse false;

    const exceptions_to_assertions = b.option(bool, "exceptions_to_assertions", "Instead of throwing exceptions assert") orelse false;

    const disable_glsl = b.option(bool, "no_glsl", "Disable GLSL target support.") orelse false;
    const disable_hlsl = b.option(bool, "no_hlsl", "Disable HLSL target support.") orelse false;
    const disable_msl = b.option(bool, "no_msl", "Disable MSL target support.") orelse false;
    const disable_cpp = b.option(bool, "no_cpp", "Disable C++ target support.") orelse false;
    const disable_reflect = b.option(bool, "no_reflect", "Disable JSON reflection target support.") orelse false;
    const disable_util = b.option(bool, "no_util", "Disable util module support.") orelse false;

    const force_stl_types = b.option(bool, "force_stl_types", "Force use of STL types instead of STL replacements in certain places. Might reduce performance.") orelse false;
 
    if (disable_glsl) 
    {
        if (!disable_hlsl)
        {
            log.err("HLSL support requires GLSL support. Skip building HLSL with -Dno_hlsl or disable -Dno_glsl flag.", .{});
            std.process.exit(1);
        }

        if (!disable_msl)
        {
            log.err("MSL support requires GLSL support. Skip building MSL with -Dno_msl or disable -Dno_glsl flag.", .{});
            std.process.exit(1);
        }

        if (!disable_cpp)
        {
            log.err("CPP support requires GLSL support. Skip building CPP with -Dno_cpp or disable -Dno_glsl flag.", .{});
            std.process.exit(1);
        }

        if (!disable_reflect)
        {
            log.err("Reflection support requires GLSL support. Skip building reflection with -Dno_reflect or disable -Dno_glsl flag.", .{});
            std.process.exit(1);
        }
    }

    var cppflags = std.ArrayList([]const u8).init(b.allocator);

    if (!debug) 
    {
        try cppflags.append("-g0");
    }

    try cppflags.append("-std=c++11");

    const base_flags = &.{ 
        "-Wall",
        "-Wextra",
        "-Wshadow",
        "-Wno-deprecated-declarations"
    };

    try cppflags.appendSlice(base_flags);

// ------------------
// SPIRV-Cross
// ------------------

    var lib: *std.Build.Step.Compile = undefined;

    if (shared) {
        lib = b.addSharedLibrary(.{
            .name = "spirv-cross",
            .optimize = optimize,
            .target = target,
        });

        if (target.result.os.tag == .windows) {
            lib.defineCMacro("SPVC_PUBLIC_API", "__declspec(dllexport)");
        } else {
            lib.defineCMacro("SPVC_PUBLIC_API", "__attribute__((visibility(\"default\")))");
        }
    } else {
        lib = b.addStaticLibrary(.{
            .name = "spirv-cross",
            .optimize = optimize,
            .target = target,
        });
    }

    if (force_stl_types)
    {
        lib.defineCMacro("SPIRV_CROSS_FORCE_STL_TYPES", "");
    }

    if (exceptions_to_assertions)
    {
        lib.defineCMacro("SPIRV_CROSS_EXCEPTIONS_TO_ASSERTIONS", "");
        try cppflags.append("-fno-exceptions");
    }

    const sources = spirv_cross_core_sources ++
        spirv_cross_c_sources;

    lib.addCSourceFiles(.{
        .files = &sources,
        .flags = cppflags.items,
    });

    if (!disable_glsl)
    {
        lib.addCSourceFiles(.{
            .files = &spirv_cross_glsl_sources,
            .flags = cppflags.items,
        });

        lib.defineCMacro("SPIRV_CROSS_C_API_GLSL", "1");
    }

    if (!disable_hlsl)
    {
        lib.addCSourceFiles(.{
            .files = &spirv_cross_hlsl_sources,
            .flags = cppflags.items,
        });

        lib.defineCMacro("SPIRV_CROSS_C_API_HLSL", "1");
    }

    if (!disable_msl)
    {
        lib.addCSourceFiles(.{
            .files = &spirv_cross_msl_sources,
            .flags = cppflags.items,
        });

        lib.defineCMacro("SPIRV_CROSS_C_API_MSL", "1");
    }

    if (!disable_cpp)
    {
        lib.addCSourceFiles(.{
            .files = &spirv_cross_cpp_sources,
            .flags = cppflags.items,
        });

        lib.defineCMacro("SPIRV_CROSS_C_API_CPP", "1");
    }

    if (!disable_reflect)
    {
        lib.addCSourceFiles(.{
            .files = &spirv_cross_reflect_sources,
            .flags = cppflags.items,
        });

        lib.defineCMacro("SPIRV_CROSS_C_API_REFLECT", "1");
    }

    if (!disable_util)
    {
        lib.addCSourceFiles(.{
            .files = &spirv_cross_util_sources,
            .flags = cppflags.items,
        });
    }

    lib.addIncludePath(b.path("."));

    lib.linkLibCpp();

    const install_cross_step = b.step("SPIRV-Cross", "Build and install SPIRV-Cross");
    install_cross_step.dependOn(&b.addInstallArtifact(lib, .{}).step);

    b.installArtifact(lib);
}

const spirv_cross_core_sources = [_][]const u8{
	"spirv_cross.cpp",
	"spirv_parser.cpp",
	"spirv_cross_parsed_ir.cpp",
	"spirv_cfg.cpp",
};

const spirv_cross_c_sources = [_][]const u8{
	"spirv_cross_c.cpp",
};

const spirv_cross_glsl_sources = [_][]const u8{
	"spirv_glsl.cpp",
};

const spirv_cross_cpp_sources = [_][]const u8{
	"spirv_cpp.cpp",
};

const spirv_cross_msl_sources = [_][]const u8{
	"spirv_msl.cpp",
};

const spirv_cross_hlsl_sources = [_][]const u8{
	"spirv_hlsl.cpp",
};

const spirv_cross_reflect_sources = [_][]const u8{
	"spirv_reflect.cpp",
};

const spirv_cross_util_sources = [_][]const u8{
	"spirv_cross_util.cpp",
};
