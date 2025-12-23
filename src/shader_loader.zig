const std = @import("std");
const c = @import("c.zig").c;
const gpu = @import("gpu.zig");

pub const ShaderSet = struct {
    vertex: gpu.Shader,
    fragment: gpu.Shader,

    pub fn load(device: *c.SDL_GPUDevice, allocator: std.mem.Allocator) !ShaderSet {
        // Try to compile shaders first
        try compileShader("shaders/triangle.vert.glsl", "shaders/triangle.vert.spv", "vertex");
        try compileShader("shaders/triangle.frag.glsl", "shaders/triangle.frag.spv", "fragment");
        const vert_spv = try loadShaderFile("shaders/triangle.vert.spv", allocator);
        errdefer allocator.free(vert_spv);
        const frag_spv = try loadShaderFile("shaders/triangle.frag.spv", allocator);
        errdefer allocator.free(frag_spv);

        const vertex_shader = gpu.Shader.init(device, vert_spv, c.SDL_GPU_SHADERSTAGE_VERTEX) catch |err| {
            allocator.free(vert_spv);
            allocator.free(frag_spv);
            std.debug.print("Failed to create vertex shader. Make sure shaders are compiled.\n", .{});
            std.debug.print("Run: glslc -fshader-stage=vertex shaders/triangle.vert.glsl -o shaders/triangle.vert.spv\n", .{});
            return err;
        };

        const fragment_shader = gpu.Shader.init(device, frag_spv, c.SDL_GPU_SHADERSTAGE_FRAGMENT) catch |err| {
            allocator.free(vert_spv);
            allocator.free(frag_spv);
            vertex_shader.deinit();
            std.debug.print("Failed to create fragment shader. Make sure shaders are compiled.\n", .{});
            std.debug.print("Run: glslc -fshader-stage=fragment shaders/triangle.frag.glsl -o shaders/triangle.frag.spv\n", .{});
            return err;
        };

        allocator.free(vert_spv);
        allocator.free(frag_spv);

        std.debug.print("Shaders loaded successfully\n", .{});

        return ShaderSet{
            .vertex = vertex_shader,
            .fragment = fragment_shader,
        };
    }

    pub fn deinit(self: ShaderSet) void {
        self.vertex.deinit();
        self.fragment.deinit();
    }
};

pub fn reloadShaders(device: *c.SDL_GPUDevice, shader_set: *ShaderSet, allocator: std.mem.Allocator) !bool {
    std.debug.print("Reloading shaders...\n", .{});

    const old_vertex = shader_set.vertex;
    const old_fragment = shader_set.fragment;

    const new_set = ShaderSet.load(device, allocator) catch |err| {
        std.debug.print("Failed to reload shaders, keeping old ones: {}\n", .{err});
        return false;
    };

    old_vertex.deinit();
    old_fragment.deinit();

    shader_set.vertex = new_set.vertex;
    shader_set.fragment = new_set.fragment;

    std.debug.print("Shaders reloaded successfully!\n", .{});
    return true;
}

fn compileShader(glsl_path: []const u8, spv_path: []const u8, stage: []const u8) !void {
    std.debug.print("Compiling {s}...\n", .{glsl_path});
    
    var stage_arg_buf: [64]u8 = undefined;
    const stage_arg = try std.fmt.bufPrint(&stage_arg_buf, "-fshader-stage={s}", .{stage});
    
    const result = std.process.Child.run(.{
        .allocator = std.heap.page_allocator,
        .argv = &[_][]const u8{
            "glslc",
            stage_arg,
            glsl_path,
            "-o",
            spv_path,
        },
    }) catch |err| {
        std.debug.print("Failed to run glslc. Make sure it's installed and in PATH.\n", .{});
        std.debug.print("Error: {}\n", .{err});
        return err;
    };
    defer std.heap.page_allocator.free(result.stdout);
    defer std.heap.page_allocator.free(result.stderr);

    if (result.term.Exited != 0) {
        std.debug.print("Shader compilation failed for {s}:\n", .{glsl_path});
        if (result.stderr.len > 0) {
            std.debug.print("{s}\n", .{result.stderr});
        }
        return error.ShaderCompilationFailed;
    }

    std.debug.print("Compiled {s} -> {s}\n", .{glsl_path, spv_path});
}

fn loadShaderFile(path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    return std.fs.cwd().readFileAlloc(allocator, path, 100000) catch |err| {
        std.debug.print("Failed to load shader file: {s}\n", .{path});
        std.debug.print("Error: {}\n", .{err});
        return err;
    };
}
