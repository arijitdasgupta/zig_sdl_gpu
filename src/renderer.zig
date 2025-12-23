const std = @import("std");
const c = @import("c.zig").c;

pub const Renderer = struct {
    device: *c.SDL_GPUDevice,
    window: *c.SDL_Window,
    pipeline: *c.SDL_GPUGraphicsPipeline,
    vertex_buffer: *c.SDL_GPUBuffer,
    vertex_count: u32,

    pub fn init(
        device: *c.SDL_GPUDevice,
        window: *c.SDL_Window,
        pipeline: *c.SDL_GPUGraphicsPipeline,
        vertex_buffer: *c.SDL_GPUBuffer,
        vertex_count: u32,
    ) Renderer {
        return Renderer{
            .device = device,
            .window = window,
            .pipeline = pipeline,
            .vertex_buffer = vertex_buffer,
            .vertex_count = vertex_count,
        };
    }

    pub fn render(self: Renderer) void {
        const cmd_buffer = c.SDL_AcquireGPUCommandBuffer(self.device);
        if (cmd_buffer == null) return;

        var swapchain_texture: ?*c.SDL_GPUTexture = null;
        if (!c.SDL_AcquireGPUSwapchainTexture(cmd_buffer, self.window, &swapchain_texture, null, null)) {
            return;
        }

        if (swapchain_texture != null) {
            const color_target = c.SDL_GPUColorTargetInfo{
                .texture = swapchain_texture,
                .mip_level = 0,
                .layer_or_depth_plane = 0,
                .clear_color = .{ .r = 0.2, .g = 0.3, .b = 0.3, .a = 1.0 },
                .load_op = c.SDL_GPU_LOADOP_CLEAR,
                .store_op = c.SDL_GPU_STOREOP_STORE,
                .resolve_texture = null,
                .resolve_mip_level = 0,
                .resolve_layer = 0,
                .cycle = false,
                .cycle_resolve_texture = false,
                .padding1 = 0,
                .padding2 = 0,
            };

            const render_pass = c.SDL_BeginGPURenderPass(cmd_buffer, &color_target, 1, null);
            c.SDL_BindGPUGraphicsPipeline(render_pass, self.pipeline);

            const viewport = c.SDL_GPUViewport{
                .x = 0,
                .y = 0,
                .w = 800,
                .h = 600,
                .min_depth = 0.0,
                .max_depth = 1.0,
            };
            c.SDL_SetGPUViewport(render_pass, &viewport);

            const scissor = c.SDL_Rect{
                .x = 0,
                .y = 0,
                .w = 800,
                .h = 600,
            };
            c.SDL_SetGPUScissor(render_pass, &scissor);

            const buffer_binding = c.SDL_GPUBufferBinding{
                .buffer = self.vertex_buffer,
                .offset = 0,
            };
            c.SDL_BindGPUVertexBuffers(render_pass, 0, &buffer_binding, 1);
            c.SDL_DrawGPUPrimitives(render_pass, self.vertex_count, 1, 0, 0);
            c.SDL_EndGPURenderPass(render_pass);
        }

        _ = c.SDL_SubmitGPUCommandBuffer(cmd_buffer);
    }
};
