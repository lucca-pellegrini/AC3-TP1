// SPDX-License-Identifier: ISC
// SPDX-FileCopyrightText: Copyright © 2026 Lucca M. A. Pellegrini <lucca@verticordia.com>

const std = @import("std");

pub fn build(b: *std.Build) void {
    // Target with static linking to avoid cross-platform simulation issues.
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .x86_64,
            .os_tag = .linux,
            .abi = .musl,
        },
    });

    const optimize = b.standardOptimizeOption(.{});

    // Set proper paths to headers and libraries.
    const misc_include = b.path("include");
    const gem5_include = b.path("gem5/include");
    const m5_lib = b.path("gem5/util/m5/build/x86/out/libm5.a");

    // Define workload configurations
    // First element is workload name, second is real run dataset size
    const workload_configs = [_]struct {
        name: []const u8,
        real_dataset: []const u8,
    }{
        .{ .name = "seidel-2d", .real_dataset = "MEDIUM_DATASET" },
        .{ .name = "jacobi-2d", .real_dataset = "MEDIUM_DATASET" },
        .{ .name = "floyd-warshall", .real_dataset = "SMALL_DATASET" }, // Can also use MEDIUM_DATASET
        .{ .name = "gemm", .real_dataset = "MEDIUM_DATASET" },
        .{ .name = "atax", .real_dataset = "LARGE_DATASET" }, // Can also use MEDIUM_DATASET
    };

    // Additional workloads that don't have specific requirements
    const other_workloads = [_][]const u8{
        "array_stride",
        "matrix_multiply",
        "random_access",
    };

    // Build debug versions with MINI dataset and -test suffix
    for (workload_configs) |config| {
        const test_exe = b.addExecutable(.{
            .name = b.fmt("{s}-test", .{config.name}),
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });

        test_exe.addCSourceFile(.{
            .file = b.path(b.fmt("workloads/{s}.c", .{config.name})),
            .flags = &[_][]const u8{
                "-std=c99",
                "-Wall",
                "-Wextra",
                "-pedantic",
                "-D_GNU_SOURCE",
                "-DMINI_DATASET",
                "-O3",
            },
        });
        test_exe.addCSourceFile(.{
            .file = b.path("workloads/polybench.c"),
            .flags = &[_][]const u8{
                "-std=c99",
                "-Wall",
                "-Wextra",
                "-pedantic",
                "-D_GNU_SOURCE",
                "-DMINI_DATASET",
                "-O3",
            },
        });

        test_exe.root_module.addIncludePath(misc_include);
        test_exe.root_module.addIncludePath(gem5_include);
        test_exe.root_module.addObjectFile(m5_lib);

        b.installArtifact(test_exe);

        // Build real run version with specified dataset
        const real_exe = b.addExecutable(.{
            .name = config.name,
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });

        // Real run dataset executable.
        real_exe.addCSourceFile(.{
            .file = b.path(b.fmt("workloads/{s}.c", .{config.name})),
            .flags = &[_][]const u8{
                "-std=c99",
                "-Wall",
                "-Wextra",
                "-pedantic",
                "-D_GNU_SOURCE",
                b.fmt("-D{s}", .{config.real_dataset}),
                "-O3",
            },
        });
        real_exe.addCSourceFile(.{
            .file = b.path("workloads/polybench.c"),
            .flags = &[_][]const u8{
                "-std=c99",
                "-Wall",
                "-Wextra",
                "-pedantic",
                "-D_GNU_SOURCE",
                b.fmt("-D{s}", .{config.real_dataset}),
                "-O3",
            },
        });

        real_exe.root_module.addIncludePath(misc_include);
        real_exe.root_module.addIncludePath(gem5_include);
        real_exe.root_module.addObjectFile(m5_lib);

        b.installArtifact(real_exe);
    }

    // Build other workloads that don't have specific dataset requirements
    // These will just use default settings
    for (other_workloads) |workload_name| {
        // Debug version with MINI dataset
        const test_exe = b.addExecutable(.{
            .name = b.fmt("{s}-test", .{workload_name}),
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });

        test_exe.addCSourceFile(.{
            .file = b.path(b.fmt("workloads/{s}.c", .{workload_name})),
            .flags = &[_][]const u8{
                "-std=c99",
                "-Wall",
                "-Wextra",
                "-pedantic",
                "-D_GNU_SOURCE",
                "-DMINI_DATASET",
                "-O3",
            },
        });
        test_exe.addCSourceFile(.{
            .file = b.path("workloads/polybench.c"),
            .flags = &[_][]const u8{
                "-std=c99",
                "-Wall",
                "-Wextra",
                "-pedantic",
                "-D_GNU_SOURCE",
                "-DMINI_DATASET",
                "-O3",
            },
        });

        test_exe.root_module.addIncludePath(misc_include);
        test_exe.root_module.addIncludePath(gem5_include);
        test_exe.root_module.addObjectFile(m5_lib);

        b.installArtifact(test_exe);

        // Real version (default dataset)
        const real_exe = b.addExecutable(.{
            .name = workload_name,
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });

        real_exe.addCSourceFile(.{
            .file = b.path(b.fmt("workloads/{s}.c", .{workload_name})),
            .flags = &[_][]const u8{
                "-std=c99",
                "-Wall",
                "-Wextra",
                "-pedantic",
                "-D_GNU_SOURCE",
                "-O3",
            },
        });

        real_exe.root_module.addIncludePath(gem5_include);
        real_exe.root_module.addObjectFile(m5_lib);

        b.installArtifact(real_exe);
    }

    // Build analyzer
    const analyze = b.addExecutable(.{
        .name = "analyze",
        .root_module = b.createModule(.{
            .root_source_file = b.path("analyze.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(analyze);

    const run_analyze = b.addRunArtifact(analyze);
    if (b.args) |args| {
        run_analyze.addArgs(args);
    }
    const analyze_step = b.step("analyze", "Analyze gem5 cache statistics");
    analyze_step.dependOn(&run_analyze.step);
}
