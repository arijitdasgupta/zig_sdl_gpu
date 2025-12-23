const std = @import("std");
const c = @import("c.zig").c;

pub fn initDevice() !struct { device: *c.SDL_GPUDevice, window: *c.SDL_Window } {
        if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
            std.debug.print("SDL Init failed: {s}\n", .{c.SDL_GetError()});
            return error.SDLInitFailed;
        }

        const window = c.SDL_CreateWindow(
            "SDL GPU Triangle",
            800,
            600,
            0,
        ) orelse {
            std.debug.print("Window creation failed: {s}\n", .{c.SDL_GetError()});
            return error.WindowCreationFailed;
        };

        const device = c.SDL_CreateGPUDevice(
            c.SDL_GPU_SHADERFORMAT_SPIRV,
            true,
            null,
        ) orelse {
            std.debug.print("GPU device creation failed: {s}\n", .{c.SDL_GetError()});
            return error.GPUDeviceCreationFailed;
        };

        const driver_name = c.SDL_GetGPUDeviceDriver(device);
        std.debug.print("GPU Device: {s}\n", .{driver_name});

        if (!c.SDL_ClaimWindowForGPUDevice(device, window)) {
            std.debug.print("Failed to claim window: {s}\n", .{c.SDL_GetError()});
            return error.ClaimWindowFailed;
        }

        return .{
            .device = device,
            .window = window,
        };
}

pub fn deinitDevice(device: *c.SDL_GPUDevice, window: *c.SDL_Window) void {
    c.SDL_ReleaseWindowFromGPUDevice(device, window);
    c.SDL_DestroyGPUDevice(device);
    c.SDL_DestroyWindow(window);
    c.SDL_Quit();
}

pub fn createBuffer(device: *c.SDL_GPUDevice, data: []const u8) !*c.SDL_GPUBuffer {
        const vertex_buffer = c.SDL_CreateGPUBuffer(
            device,
            &c.SDL_GPUBufferCreateInfo{
                .usage = c.SDL_GPU_BUFFERUSAGE_VERTEX,
                .size = @intCast(data.len),
                .props = 0,
            },
        ) orelse {
            std.debug.print("Vertex buffer creation failed: {s}\n", .{c.SDL_GetError()});
            return error.BufferCreationFailed;
        };

        const transfer_buffer = c.SDL_CreateGPUTransferBuffer(
            device,
            &c.SDL_GPUTransferBufferCreateInfo{
                .usage = c.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
                .size = @intCast(data.len),
                .props = 0,
            },
        ) orelse {
            std.debug.print("Transfer buffer creation failed: {s}\n", .{c.SDL_GetError()});
            return error.TransferBufferCreationFailed;
        };
        defer c.SDL_ReleaseGPUTransferBuffer(device, transfer_buffer);

        const transfer_data = c.SDL_MapGPUTransferBuffer(device, transfer_buffer, false);
        @memcpy(@as([*]u8, @ptrCast(transfer_data))[0..data.len], data);
        c.SDL_UnmapGPUTransferBuffer(device, transfer_buffer);

        const upload_cmd = c.SDL_AcquireGPUCommandBuffer(device);
        const copy_pass = c.SDL_BeginGPUCopyPass(upload_cmd);
        c.SDL_UploadToGPUBuffer(
            copy_pass,
            &c.SDL_GPUTransferBufferLocation{
                .transfer_buffer = transfer_buffer,
                .offset = 0,
            },
            &c.SDL_GPUBufferRegion{
                .buffer = vertex_buffer,
                .offset = 0,
                .size = @intCast(data.len),
            },
            false,
        );
        c.SDL_EndGPUCopyPass(copy_pass);
        _ = c.SDL_SubmitGPUCommandBuffer(upload_cmd);
        _ = c.SDL_WaitForGPUIdle(device);

        return vertex_buffer;
}

pub const Shader = struct {
    shader: *c.SDL_GPUShader,
    device: *c.SDL_GPUDevice,

    pub fn init(device: *c.SDL_GPUDevice, code: []const u8, stage: c.SDL_GPUShaderStage) !Shader {
        const shader = c.SDL_CreateGPUShader(
            device,
            &c.SDL_GPUShaderCreateInfo{
                .code_size = code.len,
                .code = code.ptr,
                .entrypoint = "main",
                .format = c.SDL_GPU_SHADERFORMAT_SPIRV,
                .stage = stage,
                .num_samplers = 0,
                .num_storage_textures = 0,
                .num_storage_buffers = 0,
                .num_uniform_buffers = 0,
                .props = 0,
            },
        ) orelse {
            std.debug.print("Shader creation failed: {s}\n", .{c.SDL_GetError()});
            return error.ShaderCreationFailed;
        };

        return Shader{
            .shader = shader,
            .device = device,
        };
    }

    pub fn deinit(self: Shader) void {
        c.SDL_ReleaseGPUShader(self.device, self.shader);
    }
};

pub const Pipeline = struct {
    pipeline: *c.SDL_GPUGraphicsPipeline,
    device: *c.SDL_GPUDevice,

    pub fn init(
        device: *c.SDL_GPUDevice,
        window: *c.SDL_Window,
        vertex_shader: *c.SDL_GPUShader,
        fragment_shader: *c.SDL_GPUShader,
        vertex_stride: u32,
    ) !Pipeline {
        const pipeline = c.SDL_CreateGPUGraphicsPipeline(
            device,
            &c.SDL_GPUGraphicsPipelineCreateInfo{
                .vertex_shader = vertex_shader,
                .fragment_shader = fragment_shader,
                .vertex_input_state = c.SDL_GPUVertexInputState{
                    .vertex_buffer_descriptions = &[_]c.SDL_GPUVertexBufferDescription{
                        .{
                            .slot = 0,
                            .pitch = vertex_stride,
                            .input_rate = c.SDL_GPU_VERTEXINPUTRATE_VERTEX,
                            .instance_step_rate = 0,
                        },
                    },
                    .num_vertex_buffers = 1,
                    .vertex_attributes = &[_]c.SDL_GPUVertexAttribute{
                        .{
                            .location = 0,
                            .buffer_slot = 0,
                            .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3,
                            .offset = 0,
                        },
                        .{
                            .location = 1,
                            .buffer_slot = 0,
                            .format = c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4,
                            .offset = 12,
                        },
                    },
                    .num_vertex_attributes = 2,
                },
                .primitive_type = c.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
                .target_info = c.SDL_GPUGraphicsPipelineTargetInfo{
                    .color_target_descriptions = &[_]c.SDL_GPUColorTargetDescription{
                        .{
                            .format = c.SDL_GetGPUSwapchainTextureFormat(device, window),
                            .blend_state = c.SDL_GPUColorTargetBlendState{
                                .src_color_blendfactor = c.SDL_GPU_BLENDFACTOR_SRC_ALPHA,
                                .dst_color_blendfactor = c.SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
                                .color_blend_op = c.SDL_GPU_BLENDOP_ADD,
                                .src_alpha_blendfactor = c.SDL_GPU_BLENDFACTOR_ONE,
                                .dst_alpha_blendfactor = c.SDL_GPU_BLENDFACTOR_ZERO,
                                .alpha_blend_op = c.SDL_GPU_BLENDOP_ADD,
                                .color_write_mask = 0xF,
                                .enable_blend = false,
                                .enable_color_write_mask = false,
                                .padding1 = 0,
                                .padding2 = 0,
                            },
                        },
                    },
                    .num_color_targets = 1,
                    .depth_stencil_format = c.SDL_GPU_TEXTUREFORMAT_INVALID,
                    .has_depth_stencil_target = false,
                },
                .rasterizer_state = c.SDL_GPURasterizerState{
                    .fill_mode = c.SDL_GPU_FILLMODE_FILL,
                    .cull_mode = c.SDL_GPU_CULLMODE_NONE,
                    .front_face = c.SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE,
                    .depth_bias_constant_factor = 0.0,
                    .depth_bias_clamp = 0.0,
                    .depth_bias_slope_factor = 0.0,
                    .enable_depth_bias = false,
                    .enable_depth_clip = false,
                    .padding1 = 0,
                    .padding2 = 0,
                },
                .multisample_state = c.SDL_GPUMultisampleState{
                    .sample_count = c.SDL_GPU_SAMPLECOUNT_1,
                    .sample_mask = 0,
                    .enable_mask = false,
                    .padding1 = 0,
                    .padding2 = 0,
                },
                .depth_stencil_state = c.SDL_GPUDepthStencilState{
                    .compare_op = c.SDL_GPU_COMPAREOP_INVALID,
                    .back_stencil_state = .{
                        .fail_op = c.SDL_GPU_STENCILOP_INVALID,
                        .pass_op = c.SDL_GPU_STENCILOP_INVALID,
                        .depth_fail_op = c.SDL_GPU_STENCILOP_INVALID,
                        .compare_op = c.SDL_GPU_COMPAREOP_INVALID,
                    },
                    .front_stencil_state = .{
                        .fail_op = c.SDL_GPU_STENCILOP_INVALID,
                        .pass_op = c.SDL_GPU_STENCILOP_INVALID,
                        .depth_fail_op = c.SDL_GPU_STENCILOP_INVALID,
                        .compare_op = c.SDL_GPU_COMPAREOP_INVALID,
                    },
                    .compare_mask = 0,
                    .write_mask = 0,
                    .enable_depth_test = false,
                    .enable_depth_write = false,
                    .enable_stencil_test = false,
                    .padding1 = 0,
                    .padding2 = 0,
                    .padding3 = 0,
                },
                .props = 0,
            },
        ) orelse {
            std.debug.print("Pipeline creation failed: {s}\n", .{c.SDL_GetError()});
            return error.PipelineCreationFailed;
        };

        return Pipeline{
            .pipeline = pipeline,
            .device = device,
        };
    }

    pub fn deinit(self: Pipeline) void {
        c.SDL_ReleaseGPUGraphicsPipeline(self.device, self.pipeline);
    }
};
