// SPDX-License-Identifier: ISC
// SPDX-FileCopyrightText: Copyright © 2026 Lucca M. A. Pellegrini <lucca@verticordia.com>

const std = @import("std");
const builtin = @import("builtin");

// Possible targets for the build
const known_targets = [_][]const u8{
    "report",
    "visualize",
    "simulations",
    "workloads",
    "gem5",
    "m5",
    "init-gem5",
    "setup-python",
    "check-deps",
    "analyze",
    "install",
};

// Struct representing Python version and installation information
const PythonInfo = struct {
    base_prefix: []const u8,
    libdir: []const u8,
    ver_mm: []const u8, // e.g. "3.14"

    fn deinit(self: *const PythonInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.base_prefix);
        allocator.free(self.libdir);
        allocator.free(self.ver_mm);
    }
};

// Struct describing each executable dependency, what it does, and what it's
// needed by.
const DepInfo = struct {
    cmd: []const u8,
    description: []const u8,
    required_for: []const []const u8,
};

// List of all needed commands, and why they're needed
const all_dependencies = [_]DepInfo{
    .{ .cmd = "git", .description = "Version control (for gem5 submodule)", .required_for = &.{"init-gem5"} },
    .{ .cmd = "uv", .description = "Python environment manager", .required_for = &.{ "gem5", "m5", "workloads", "simulations", "visualize", "default" } },
    .{ .cmd = "cc", .description = "C compiler", .required_for = &.{ "gem5", "m5", "workloads", "simulations", "visualize", "default" } },
    .{ .cmd = "c++", .description = "C++ compiler", .required_for = &.{ "gem5", "m5", "workloads", "simulations", "visualize", "default" } },
    .{ .cmd = "m4", .description = "Macro processor", .required_for = &.{ "gem5", "m5", "workloads", "simulations", "visualize", "default" } },
    .{ .cmd = "dot", .description = "Graph visualization (for diagrams)", .required_for = &.{ "simulations", "report" } },
    .{ .cmd = "make", .description = "Build automation (for report)", .required_for = &.{"report"} },
    .{ .cmd = "latex", .description = "LaTeX engine (for matplotlib usetex in visualizations)", .required_for = &.{ "visualize", "report" } },
    .{ .cmd = "dvipng", .description = "DVI to PNG converter (for matplotlib usetex)", .required_for = &.{ "visualize", "report" } },
    .{ .cmd = "pdflatex", .description = "LaTeX compiler (for report)", .required_for = &.{"report"} },
    .{ .cmd = "bibtex", .description = "Bibliography processor (for report)", .required_for = &.{"report"} },
};

// Targets and their transitive dependencies (what targets they depend on)
const target_deps = struct {
    const map = .{
        .{ "check-deps", &[_][]const u8{} },
        .{ "setup-python", &[_][]const u8{"check-deps"} },
        .{ "init-gem5", &[_][]const u8{"check-deps"} },
        .{ "gem5", &[_][]const u8{ "setup-python", "init-gem5" } },
        .{ "m5", &[_][]const u8{ "setup-python", "init-gem5" } },
        .{ "workloads", &[_][]const u8{"m5"} },
        .{ "simulations", &[_][]const u8{ "gem5", "workloads" } },
        .{ "visualize", &[_][]const u8{"simulations"} },
        .{ "report", &[_][]const u8{"visualize"} },
        .{ "default", &[_][]const u8{"workloads"} },
        .{ "analyze", &[_][]const u8{} },
    };

    fn get(target: []const u8) []const []const u8 {
        inline for (map) |entry| {
            if (std.mem.eql(u8, target, entry[0])) return entry[1];
        }
        return &[_][]const u8{};
    }
};

// Main build function
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

    // Check dependencies
    const check_deps = b.step("check-deps", "Check all required dependencies");
    check_deps.makeFn = checkDependencies;

    // Setup Python Environment
    const setup_python = b.step("setup-python", "Setup Python environment with uv");
    setup_python.dependOn(check_deps);
    setup_python.makeFn = setupPythonEnvironment;

    // Initialize gem5 submodule
    const init_gem5 = b.step("init-gem5", "Initialize and update gem5 submodule");
    init_gem5.dependOn(check_deps);
    init_gem5.makeFn = initGem5Submodule;

    // Build gem5 simulator
    const build_gem5 = b.step("gem5", "Build gem5 simulator (takes ~50 minutes)");
    build_gem5.dependOn(setup_python);
    build_gem5.dependOn(init_gem5);
    build_gem5.makeFn = buildGem5Simulator;

    // Build gem5 control library (m5)
    const build_m5 = b.step("m5", "Build gem5 m5 control library");
    build_m5.dependOn(setup_python);
    build_m5.dependOn(init_gem5);
    build_m5.makeFn = buildM5Library;

    // Build workloads

    // Set proper paths to headers and libraries.
    const misc_include = b.path("include");
    const gem5_include = b.path("gem5/include");
    const m5_lib = b.path("gem5/util/m5/build/x86/out/libm5.a");

    // Define dataset size configuration for each workload
    const workload_configs = [_]struct {
        name: []const u8,
        real_dataset: []const u8,
    }{
        .{ .name = "seidel-2d", .real_dataset = "MEDIUM_DATASET" },
        .{ .name = "jacobi-2d", .real_dataset = "MEDIUM_DATASET" },
        .{ .name = "floyd-warshall", .real_dataset = "SMALL_DATASET" },
        .{ .name = "gemm", .real_dataset = "MEDIUM_DATASET" },
        .{ .name = "atax", .real_dataset = "LARGE_DATASET" },
    };

    // Handwritten workloads that don't have specific settings
    const other_workloads = [_][]const u8{
        "array_stride",
        "matrix_multiply",
        "random_access",
    };

    const build_workloads = b.step("workloads", "Build and install all workloads");
    build_workloads.dependOn(build_m5);
    build_workloads.dependOn(b.getInstallStep()); // Ensure binaries are put in zig-out

    // Build debug PolyBench versions with MINI dataset and -test suffix
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
        test_exe.step.dependOn(build_m5); // Linking stage depends on libm5.a
        build_workloads.dependOn(&test_exe.step);

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
        real_exe.step.dependOn(build_m5);
        build_workloads.dependOn(&real_exe.step);
    }

    // Build other workloads that don't have specific settings
    for (other_workloads) |workload_name| {
        const exe = b.addExecutable(.{
            .name = workload_name,
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });

        exe.addCSourceFile(.{
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

        exe.root_module.addIncludePath(gem5_include);
        exe.root_module.addObjectFile(m5_lib);

        b.installArtifact(exe);
        exe.step.dependOn(build_m5); // Linking stage depends on libm5.a
        build_workloads.dependOn(&exe.step);
    }

    // Print a single confirmation once ALL workloads finished building
    build_workloads.makeFn = printWorkloadsBuilt;

    // Build analyzer utility
    const analyze = b.addExecutable(.{
        .name = "analyze",
        .root_module = b.createModule(.{
            .root_source_file = b.path("analyze.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(analyze);

    // Run analyze script on passed argument
    const run_analyze = b.addRunArtifact(analyze);
    if (b.args) |args| {
        run_analyze.addArgs(args);
    }
    const analyze_step = b.step("analyze", "Analyze gem5 cache statistics");
    analyze_step.dependOn(&run_analyze.step);

    // Run simulations
    const run_simulations = b.step("simulations", "Run all gem5 simulations");
    run_simulations.dependOn(build_gem5); // Ensure gem5 is built
    run_simulations.dependOn(build_workloads); // Ensure workloads are built
    build_m5.dependOn(setup_python); // Ensure venv is set up
    run_simulations.dependOn(b.getInstallStep()); // Ensure workloads are in zig-out
    run_simulations.makeFn = runSimulations;

    // Generate visualizations
    const visualize = b.step("visualize", "Generate visualization plots from results");
    visualize.dependOn(run_simulations);
    build_m5.dependOn(setup_python);
    visualize.makeFn = generateVisualizations;

    // Build the report
    const build_report = b.step("report", "Build the LaTeX report");
    build_report.dependOn(visualize);
    build_report.makeFn = buildReport;

    // Default step just builds workloads
    b.default_step = build_workloads;
}

fn setupPythonEnvironment(step: *std.Build.Step, _: std.Build.Step.MakeOptions) anyerror!void {
    const b = step.owner;
    const allocator = b.allocator;

    std.debug.print("\n\x1b[1;36m==> Setting up Python environment (uv)...\x1b[0m\n", .{});

    // Ensure CPython 3.14.3 is available (managed by uv)
    {
        std.debug.print("\x1b[1mEnsuring Python 3.14.3 is installed...\x1b[0m\n", .{});
        var child = std.process.Child.init(&[_][]const u8{ "uv", "--quiet", "python", "install", "3.14.3" }, allocator);
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;
        const term = child.spawnAndWait() catch |err| {
            std.debug.print("Failed to install Python 3.14.3: {}\n", .{err});
            return err;
        };
        if (term.Exited != 0) {
            std.debug.print("Failed to install Python 3.14.3 (exit code {})\n", .{term.Exited});
            return error.PythonInstallFailed;
        }
    }

    // Create venv if missing
    const venv_path = "gem5/venv";
    if (std.fs.cwd().statFile(venv_path)) |_| {} else |err| {
        if (err != error.FileNotFound) return err;

        std.debug.print("\x1b[1mCreating Python virtual environment...\x1b[0m\n", .{});
        var child = std.process.Child.init(&[_][]const u8{
            "uv", "venv", "--quiet", "--python", "3.14.3", "gem5/venv",
        }, allocator);
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;
        const term = child.spawnAndWait() catch |venv_err| {
            std.debug.print("Failed to create venv: {}\n", .{venv_err});
            return venv_err;
        };
        if (term.Exited != 0) {
            std.debug.print("Failed to create venv (exit code {})\n", .{term.Exited});
            return error.VenvCreationFailed;
        }
    }

    // Install Python deps into that venv
    {
        std.debug.print("\x1b[1mInstalling Python dependencies...\x1b[0m\n", .{});
        var child = std.process.Child.init(&[_][]const u8{
            "uv", "pip", "--no-progress", "install", "--python", "gem5/venv", "-r", "requirements.txt",
        }, allocator);
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;
        const term = child.spawnAndWait() catch |pip_err| {
            std.debug.print("Failed to install dependencies: {}\n", .{pip_err});
            return pip_err;
        };
        if (term.Exited != 0) {
            std.debug.print("Failed to install dependencies (exit code {})\n", .{term.Exited});
            return error.DependencyInstallFailed;
        }
    }

    std.debug.print("  \x1b[1;32m✓ Python environment ready\x1b[0m\n", .{});
}

fn initGem5Submodule(step: *std.Build.Step, _: std.Build.Step.MakeOptions) anyerror!void {
    const b = step.owner;
    const allocator = b.allocator;

    // Check if the submodule's been properly initialized
    if (std.fs.cwd().statFile("gem5/.git")) |_| {} else |err| {
        if (err == error.FileNotFound) {
            std.debug.print("\n\x1b[1;36m==> Initializing gem5 submodule...\x1b[0m\n", .{});
            const init_result = std.process.Child.run(.{
                .allocator = allocator,
                .argv = &[_][]const u8{ "git", "submodule", "update", "--init", "--recursive" },
            }) catch |init_err| {
                std.debug.print("Failed to initialize submodule: {}\n", .{init_err});
                return init_err;
            };
            defer allocator.free(init_result.stdout);
            defer allocator.free(init_result.stderr);

            if (init_result.term.Exited != 0) {
                std.debug.print("Failed to initialize submodule:\n{s}\n", .{init_result.stderr});
                return error.SubmoduleInitFailed;
            }
        } else {
            return err;
        }
    }

    std.debug.print("  \x1b[1;32m✓ gem5 submodule ready\x1b[0m\n", .{});
}

fn pythonInfoFromVenv(allocator: std.mem.Allocator) !PythonInfo {
    const py = "./gem5/venv/bin/python";

    // Get sys.base_prefix
    const base_prefix = blk: {
        const res = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{ py, "-c", "import sys; print(sys.base_prefix, end='')" },
        }) catch |err| {
            std.debug.print("Failed to query Python base_prefix: {}\n", .{err});
            return err;
        };
        defer allocator.free(res.stderr);
        if (res.term.Exited != 0) {
            defer allocator.free(res.stdout);
            std.debug.print("Failed to query Python base_prefix:\n{s}\n", .{res.stderr});
            return error.PythonQueryFailed;
        }
        break :blk res.stdout;
    };
    errdefer allocator.free(base_prefix);

    // Get libdir: use base_prefix/lib directly since uv's standalone Python
    // builds have sysconfig LIBDIR pointing to the original build path, not
    // the installed location
    const libdir = std.fmt.allocPrint(allocator, "{s}/lib", .{base_prefix}) catch return error.OutOfMemory;
    errdefer allocator.free(libdir);

    // Get version major.minor
    const ver_mm = blk: {
        const res = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{
                py,
                "-c",
                "import sys; print(f'{sys.version_info[0]}.{sys.version_info[1]}', end='')",
            },
        }) catch |err| {
            std.debug.print("Failed to query Python version: {}\n", .{err});
            return err;
        };
        defer allocator.free(res.stderr);
        if (res.term.Exited != 0) {
            defer allocator.free(res.stdout);
            std.debug.print("Failed to query Python version:\n{s}\n", .{res.stderr});
            return error.PythonQueryFailed;
        }
        break :blk res.stdout;
    };

    return PythonInfo{
        .base_prefix = base_prefix,
        .libdir = libdir,
        .ver_mm = ver_mm,
    };
}

fn buildGem5Simulator(step: *std.Build.Step, _: std.Build.Step.MakeOptions) anyerror!void {
    const b = step.owner;
    const allocator = b.allocator;

    // Build gem5 simulator if not already built
    const gem5_binary = "gem5/build/X86/gem5.fast";
    if (std.fs.cwd().statFile(gem5_binary)) |_| {} else |err| {
        if (err == error.FileNotFound) {
            std.debug.print("\n\x1b[1;36m==> Building gem5 simulator...\x1b[0m\n", .{});

            // Get number of processors for parallel build
            const nproc_result = std.process.Child.run(.{
                .allocator = allocator,
                .argv = &[_][]const u8{"nproc"},
            }) catch {
                std.debug.print("Warning: Could not determine number of processors, using 4\n", .{});
                return;
            };
            defer allocator.free(nproc_result.stdout);
            defer allocator.free(nproc_result.stderr);

            const nproc_str = std.mem.trimRight(u8, nproc_result.stdout, "\n");
            const nproc = std.fmt.parseInt(u32, nproc_str, 10) catch 4;
            const jobs = @max(1, 3 * nproc / 4); // Use 3/4 of the cores for better stability

            std.debug.print("\x1b[1mBuilding gem5 (this will take ~50 minutes)...\x1b[0m\n", .{});
            std.debug.print("\x1b[1mUsing {} parallel jobs\x1b[0m\n", .{jobs});

            const build_cmd = std.fmt.allocPrint(allocator, "-j{}", .{jobs}) catch return error.OutOfMemory;
            defer allocator.free(build_cmd);

            // Query Python info from venv to get PYTHON_CONFIG, rpath, and LD_LIBRARY_PATH
            const pyinfo = pythonInfoFromVenv(allocator) catch |perr| {
                std.debug.print("Failed to query Python info from venv: {}\n", .{perr});
                return perr;
            };
            defer pyinfo.deinit(allocator);

            std.debug.print("  Python base_prefix: {s}\n", .{pyinfo.base_prefix});
            std.debug.print("  Python libdir: {s}\n", .{pyinfo.libdir});
            std.debug.print("  Python version: {s}\n", .{pyinfo.ver_mm});

            const pyconfig_env = std.fmt.allocPrint(allocator, "PYTHON_CONFIG={s}/bin/python{s}-config", .{ pyinfo.base_prefix, pyinfo.ver_mm }) catch return error.OutOfMemory;
            defer allocator.free(pyconfig_env);

            const ldflags_env = std.fmt.allocPrint(allocator, "LDFLAGS=-Wl,-rpath,{s}", .{pyinfo.libdir}) catch return error.OutOfMemory;
            defer allocator.free(ldflags_env);

            // LD_LIBRARY_PATH is needed by SCons to find libpython.so
            const old_ldlib = std.process.getEnvVarOwned(allocator, "LD_LIBRARY_PATH") catch "";
            defer if (old_ldlib.len != 0) allocator.free(old_ldlib);
            const ldlib_env = if (old_ldlib.len != 0)
                (std.fmt.allocPrint(allocator, "LD_LIBRARY_PATH={s}:{s}", .{ pyinfo.libdir, old_ldlib }) catch return error.OutOfMemory)
            else
                (std.fmt.allocPrint(allocator, "LD_LIBRARY_PATH={s}", .{pyinfo.libdir}) catch return error.OutOfMemory);
            defer allocator.free(ldlib_env);

            // PATH must include the venv bin so that `python3` resolves for
            // gem5 build scripts. We have to use an absolute path because
            // SCons changes directory with -C.
            const cwd = std.fs.cwd().realpathAlloc(allocator, ".") catch return error.OutOfMemory;
            defer allocator.free(cwd);
            const venv_bin = std.fmt.allocPrint(allocator, "{s}/gem5/venv/bin", .{cwd}) catch return error.OutOfMemory;
            defer allocator.free(venv_bin);

            const old_path = std.process.getEnvVarOwned(allocator, "PATH") catch "";
            defer if (old_path.len != 0) allocator.free(old_path);
            const path_env = if (old_path.len != 0)
                (std.fmt.allocPrint(allocator, "PATH={s}:{s}", .{ venv_bin, old_path }) catch return error.OutOfMemory)
            else
                (std.fmt.allocPrint(allocator, "PATH={s}", .{venv_bin}) catch return error.OutOfMemory);
            defer allocator.free(path_env);

            std.debug.print("  {s}\n", .{ldlib_env});
            std.debug.print("  {s}\n", .{ldflags_env});
            std.debug.print("  {s}\n", .{pyconfig_env});
            std.debug.print("  {s}\n", .{path_env});

            const scons_path = std.fmt.allocPrint(allocator, "{s}/scons", .{venv_bin}) catch return error.OutOfMemory;
            defer allocator.free(scons_path);

            var child = std.process.Child.init(&[_][]const u8{
                "env",
                path_env,
                ldlib_env,
                ldflags_env,
                pyconfig_env,
                scons_path,
                "-C",
                "gem5",
                "--ignore-style",
                "gem5/build/X86/gem5.fast",
                build_cmd,
            }, allocator);
            child.stdout_behavior = .Inherit;
            child.stderr_behavior = .Inherit;
            const term = child.spawnAndWait() catch |build_err| {
                std.debug.print("Failed to build gem5: {}\n", .{build_err});
                return build_err;
            };

            if (term.Exited != 0) {
                std.debug.print("\x1b[1;31mFailed to build gem5 (exit code {})\x1b[0m\n", .{term.Exited});
                return error.Gem5BuildFailed;
            }
        } else {
            return err;
        }
    }

    std.debug.print("  \x1b[1;32m✓ gem5 simulator built\x1b[0m\n", .{});
}

fn buildM5Library(step: *std.Build.Step, _: std.Build.Step.MakeOptions) anyerror!void {
    const b = step.owner;
    const allocator = b.allocator;

    // Check if already built
    const m5_lib = "gem5/util/m5/build/x86/out/libm5.a";
    if (std.fs.cwd().statFile(m5_lib)) |_| {} else |err| {
        if (err == error.FileNotFound) {
            std.debug.print("\n\x1b[1;36m==> Building gem5 m5 control library...\x1b[0m\n", .{});

            // Query Python info from venv to get PYTHON_CONFIG, rpath, and LD_LIBRARY_PATH
            const pyinfo = pythonInfoFromVenv(allocator) catch |perr| {
                std.debug.print("Failed to query Python info from venv: {}\n", .{perr});
                return perr;
            };
            defer pyinfo.deinit(allocator);

            const pyconfig_env = std.fmt.allocPrint(allocator, "PYTHON_CONFIG={s}/bin/python{s}-config", .{ pyinfo.base_prefix, pyinfo.ver_mm }) catch return error.OutOfMemory;
            defer allocator.free(pyconfig_env);

            const ldflags_env = std.fmt.allocPrint(allocator, "LDFLAGS=-Wl,-rpath,{s}", .{pyinfo.libdir}) catch return error.OutOfMemory;
            defer allocator.free(ldflags_env);

            // LD_LIBRARY_PATH is needed by SCons to find libpython.so
            const old_ldlib = std.process.getEnvVarOwned(allocator, "LD_LIBRARY_PATH") catch "";
            defer if (old_ldlib.len != 0) allocator.free(old_ldlib);
            const ldlib_env = if (old_ldlib.len != 0)
                (std.fmt.allocPrint(allocator, "LD_LIBRARY_PATH={s}:{s}", .{ pyinfo.libdir, old_ldlib }) catch return error.OutOfMemory)
            else
                (std.fmt.allocPrint(allocator, "LD_LIBRARY_PATH={s}", .{pyinfo.libdir}) catch return error.OutOfMemory);
            defer allocator.free(ldlib_env);

            // PATH must include the venv bin so that `python3` resolves for
            // gem5 build scripts. We have to use an absolute path because
            // SCons changes directory with -C.
            const cwd = std.fs.cwd().realpathAlloc(allocator, ".") catch return error.OutOfMemory;
            defer allocator.free(cwd);
            const venv_bin = std.fmt.allocPrint(allocator, "{s}/gem5/venv/bin", .{cwd}) catch return error.OutOfMemory;
            defer allocator.free(venv_bin);

            const old_path = std.process.getEnvVarOwned(allocator, "PATH") catch "";
            defer if (old_path.len != 0) allocator.free(old_path);
            const path_env = if (old_path.len != 0)
                (std.fmt.allocPrint(allocator, "PATH={s}:{s}", .{ venv_bin, old_path }) catch return error.OutOfMemory)
            else
                (std.fmt.allocPrint(allocator, "PATH={s}", .{venv_bin}) catch return error.OutOfMemory);
            defer allocator.free(path_env);

            const scons_path = std.fmt.allocPrint(allocator, "{s}/scons", .{venv_bin}) catch return error.OutOfMemory;
            defer allocator.free(scons_path);

            var child = std.process.Child.init(&[_][]const u8{
                "env",
                path_env,
                ldlib_env,
                ldflags_env,
                pyconfig_env,
                scons_path,
                "-C",
                "gem5/util/m5",
                "build/x86/out/m5",
            }, allocator);
            child.stdout_behavior = .Inherit;
            child.stderr_behavior = .Inherit;
            const term = child.spawnAndWait() catch |build_err| {
                std.debug.print("Failed to build m5 library: {}\n", .{build_err});
                return build_err;
            };

            if (term.Exited != 0) {
                std.debug.print("\x1b[1;31mFailed to build m5 library (exit code {})\x1b[0m\n", .{term.Exited});
                return error.M5BuildFailed;
            }
        } else {
            return err;
        }
    }

    std.debug.print("  \x1b[1;32m✓ m5 control library built\x1b[0m\n", .{});
}

fn runSimulations(step: *std.Build.Step, _: std.Build.Step.MakeOptions) anyerror!void {
    const b = step.owner;
    const allocator = b.allocator;

    std.debug.print("\n\x1b[1;36m==> Running simulations...\x1b[0m\n", .{});

    // Get number of processors
    const nproc_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{"nproc"},
    }) catch {
        std.debug.print("Warning: Could not determine number of processors, using 4\n", .{});
        return;
    };
    defer allocator.free(nproc_result.stdout);
    defer allocator.free(nproc_result.stderr);

    const nproc_str = std.mem.trimRight(u8, nproc_result.stdout, "\n");
    const nproc = std.fmt.parseInt(u32, nproc_str, 10) catch 4;
    const jobs = @min(9, nproc); // Do not exceed 9 parallel jobs (OOM likely)

    const polybench_workloads = [_][]const u8{
        "atax",
        "floyd-warshall",
        "gemm",
        "jacobi-2d",
        "seidel-2d",
    };

    std.debug.print("\x1b[1mRunning simulations with {} parallel jobs...\x1b[0m\n", .{jobs});
    std.debug.print("This may take several hours depending on your system.\n", .{});

    for (polybench_workloads) |workload| {
        std.debug.print("\n\x1b[1mRunning simulations for {s}...\x1b[0m\n", .{workload});

        const workload_path = std.fmt.allocPrint(allocator, "zig-out/bin/{s}", .{workload}) catch return error.OutOfMemory;
        defer allocator.free(workload_path);

        const jobs_str = std.fmt.allocPrint(allocator, "-j{}", .{jobs}) catch return error.OutOfMemory;
        defer allocator.free(jobs_str);

        const sim_result = std.process.Child.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{
                "./gem5/venv/bin/python",
                "./run_all_simulations.py",
                "--results-dir=results",
                "gem5/build/X86/gem5.fast",
                workload_path,
                jobs_str,
                "--pin-workers",
            },
        }) catch |sim_err| {
            std.debug.print("\x1b[1;31mFailed to run simulations for {s}: {}\x1b[0m\n", .{ workload, sim_err });
            return sim_err;
        };
        defer allocator.free(sim_result.stdout);
        defer allocator.free(sim_result.stderr);

        if (sim_result.term.Exited != 0) {
            std.debug.print("\x1b[1;31mSimulations failed for {s}:\x1b[0m\n{s}\n", .{ workload, sim_result.stderr });
        } else {
            std.debug.print("  \x1b[1;32m✓ Simulations complete for {s}\x1b[0m\n", .{workload});
        }
    }
}

fn generateVisualizations(step: *std.Build.Step, _: std.Build.Step.MakeOptions) anyerror!void {
    const b = step.owner;
    const allocator = b.allocator;

    std.debug.print("\n\x1b[1;36m==> Generating visualization plots...\x1b[0m\n", .{});

    const viz_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "./gem5/venv/bin/python",
            "./visualize_results.py",
        },
    }) catch |viz_err| {
        std.debug.print("\x1b[1;31mFailed to generate visualizations: {}\x1b[0m\n", .{viz_err});
        return viz_err;
    };
    defer allocator.free(viz_result.stdout);
    defer allocator.free(viz_result.stderr);

    if (viz_result.term.Exited != 0) {
        std.debug.print("\x1b[1;31mVisualization generation failed:\x1b[0m\n{s}\n", .{viz_result.stderr});
        return error.VisualizationFailed;
    }

    std.debug.print("  \x1b[1;32m✓ Visualization plots generated\x1b[0m\n", .{});
}

fn buildReport(step: *std.Build.Step, _: std.Build.Step.MakeOptions) anyerror!void {
    const b = step.owner;
    const allocator = b.allocator;

    std.debug.print("\n\x1b[1;36m==> Building LaTeX report...\x1b[0m\n", .{});

    const report_result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "make", "-C", "report/", "all" },
    }) catch |report_err| {
        std.debug.print("\x1b[1;31mFailed to build report: {}\x1b[0m\n", .{report_err});
        return report_err;
    };
    defer allocator.free(report_result.stdout);
    defer allocator.free(report_result.stderr);

    if (report_result.term.Exited != 0) {
        std.debug.print("\x1b[1;31mReport build failed:\x1b[0m\n{s}\n", .{report_result.stderr});
        return error.ReportBuildFailed;
    }

    std.debug.print("  \x1b[1;32m✓ Report built successfully\x1b[0m\n", .{});
    std.debug.print("  ⚡ \x1b[0mThe report is available in \x1b[1mreport/main.pdf\x1b[0m\n", .{});
}

// Final confirmation after all workload artifacts and installs complete
fn printWorkloadsBuilt(_: *std.Build.Step, _: std.Build.Step.MakeOptions) anyerror!void {
    std.debug.print("  \x1b[1;32m✓ All workloads compiled and installed\x1b[0m\n", .{});
}

fn checkDependencies(step: *std.Build.Step, _: std.Build.Step.MakeOptions) anyerror!void {
    const b = step.owner;
    const allocator = b.allocator;

    std.debug.print("\x1b[1;36m==> Checking dependencies...\x1b[0m\n", .{});

    // Determine what targets are being built
    const requested_targets = getRequestedTargets(step);

    var hard_missing: u32 = 0;
    var soft_missing: u32 = 0;

    for (all_dependencies) |dep| {
        const found = checkCmd(allocator, dep.cmd);
        const is_required = isRequiredFor(dep, requested_targets);

        if (found) {
            std.debug.print("  \x1b[1;32m✓ {s}\x1b[0m: found\n", .{dep.cmd});
        } else if (is_required) {
            // Hard error if required for current target
            std.debug.print("  \x1b[1;31m✗ {s}\x1b[0m: not found - \x1b[1;31mREQUIRED\x1b[0m ({s})\n", .{ dep.cmd, dep.description });
            hard_missing += 1;
        } else {
            // Soft warning if not needed for current target
            std.debug.print("  \x1b[1;33m⚠ {s}\x1b[0m: not found - needed for: ", .{dep.cmd});
            for (dep.required_for, 0..) |target, i| {
                if (i > 0) std.debug.print(", ", .{});
                std.debug.print("{s}", .{target});
            }
            std.debug.print(" ({s})\n", .{dep.description});
            soft_missing += 1;
        }
    }

    if (hard_missing > 0) {
        std.debug.print("\n\x1b[1;31mMissing required dependencies ({} required, {} optional):\x1b[0m\n", .{ hard_missing, soft_missing });
        for (all_dependencies) |dep| {
            if (!checkCmd(allocator, dep.cmd) and isRequiredFor(dep, requested_targets)) {
                std.debug.print("  - {s} ({s})\n", .{ dep.cmd, dep.description });
            }
        }
        std.debug.print("\n\x1b[1mPlease install the missing dependencies before continuing.\x1b[0m\n", .{});
        return error.MissingDependencies;
    }

    if (soft_missing > 0) {
        std.debug.print("\n\x1b[1;33mNote:\x1b[0m {d} optional dependencies not found (not needed for current target)\n", .{soft_missing});
    }
}

/// Check if a command exists in PATH
fn checkCmd(allocator: std.mem.Allocator, cmd: []const u8) bool {
    const check_cmd = std.fmt.allocPrint(allocator, "command -v {s}", .{cmd}) catch return false;
    defer allocator.free(check_cmd);

    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "/bin/sh", "-c", check_cmd },
    }) catch return false;
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    return result.term.Exited == 0;
}

/// Check if a dependency is required for any of the given targets
fn isRequiredFor(dep: DepInfo, targets: []const []const u8) bool {
    for (targets) |target| {
        // Check direct requirement
        for (dep.required_for) |req_target| {
            if (std.mem.eql(u8, req_target, target)) return true;
        }
        // Check transitive dependencies
        const transitive = target_deps.get(target);
        for (transitive) |trans_target| {
            for (dep.required_for) |req_target| {
                if (std.mem.eql(u8, req_target, trans_target)) return true;
            }
        }
    }
    return false;
}

// Static buffer for target results
var target_result_buffer: [16][]const u8 = undefined;
var target_result_count: usize = 0;

/// Recursively find root targets starting from given step
fn findRootTargets(step: *std.Build.Step) void {
    // If this step has no dependants, it might be a root target
    if (step.dependants.items.len == 0) {
        const step_name = step.name;
        for (known_targets) |target| {
            if (std.mem.eql(u8, step_name, target)) {
                // Avoid duplicates
                var found = false;
                for (target_result_buffer[0..target_result_count]) |existing| {
                    if (std.mem.eql(u8, existing, target)) {
                        found = true;
                        break;
                    }
                }
                if (!found and target_result_count < target_result_buffer.len) {
                    target_result_buffer[target_result_count] = target;
                    target_result_count += 1;
                }
                return;
            }
        }
        return;
    }

    // Recurse up to dependants
    for (step.dependants.items) |dependant| {
        findRootTargets(dependant);
    }
}

/// Determine the target being built by walking up the dependency graph
fn getRequestedTargets(step: *std.Build.Step) []const []const u8 {
    // Reset the static buffer
    target_result_count = 0;

    findRootTargets(step);

    // Map "install" to "default", which is to install workloads
    for (target_result_buffer[0..target_result_count], 0..) |target, i| {
        if (std.mem.eql(u8, target, "install")) {
            target_result_buffer[i] = "default";
        }
    }

    // If nothing specific, assume default
    if (target_result_count == 0) {
        return &[_][]const u8{"default"};
    }

    return target_result_buffer[0..target_result_count];
}
