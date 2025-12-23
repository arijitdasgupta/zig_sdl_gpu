const std = @import("std");
const c = @import("c.zig").c;

const gpu = @import("gpu.zig");
const renderer = @import("renderer.zig");
const geometry = @import("geometry.zig");
const shader_loader = @import("shader_loader.zig");
const file_watcher = @import("file_watcher.zig");

pub fn main() !void {
    const gpu_device = try gpu.Device.init();
    defer gpu_device.deinit();

    const triangle = geometry.Triangle.init();
    const vertex_buffer = try gpu.Buffer.init(gpu_device.device, triangle.asBytes());
    defer vertex_buffer.deinit();

    var watcher = file_watcher.FileWatcher.init(std.heap.page_allocator);
    defer watcher.deinit();
    try watcher.watch("shaders/triangle.vert.glsl");
    try watcher.watch("shaders/triangle.frag.glsl");

    var shaders = try shader_loader.ShaderSet.load(gpu_device.device, std.heap.page_allocator);
    defer shaders.deinit();

    var pipeline = try gpu.Pipeline.init(
        gpu_device.device,
        gpu_device.window,
        shaders.vertex.shader,
        shaders.fragment.shader,
        @sizeOf(geometry.Vertex),
    );
    defer pipeline.deinit();

    std.debug.print("Rendering... (shaders will hot-reload when changed)\n", .{});

    var render = renderer.Renderer.init(
        gpu_device.device,
        gpu_device.window,
        pipeline.pipeline,
        vertex_buffer.buffer,
        triangle.vertexCount(),
    );

    var last_check_time = std.time.milliTimestamp();
    var running = true;
    while (running) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            if (event.type == c.SDL_EVENT_QUIT) {
                running = false;
            }
        }

        // Check for shader file changes every 500ms
        const current_time = std.time.milliTimestamp();
        if (current_time - last_check_time > 500) {
            last_check_time = current_time;
            
            if (try watcher.checkChanges()) {
                if (try shader_loader.reloadShaders(gpu_device.device, &shaders, std.heap.page_allocator)) {
                    // Recreate pipeline with new shaders
                    pipeline.deinit();
                    pipeline = try gpu.Pipeline.init(
                        gpu_device.device,
                        gpu_device.window,
                        shaders.vertex.shader,
                        shaders.fragment.shader,
                        @sizeOf(geometry.Vertex),
                    );
                    
                    // Update renderer with new pipeline
                    render.pipeline = pipeline.pipeline;
                }
            }
        }

        render.render();
    }
}
