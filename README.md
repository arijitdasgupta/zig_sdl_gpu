# SDL GPU Shader Playground in Zig

A simple GPU rendering pipeline using SDL3's GPU API and Zig. Fork it and play with shaderz.

## Features

- Almost entirely vibe coded.
- Cross-platform GPU rendering (Vulkan, D3D12, Metal via SDL3 GPU)
- SPIR-V shader pipeline
- Clean modular architecture
- Colored triangle with vertex interpolation

## Prerequisites

- Zig 0.15.2 or later
- SDL3 (with GPU support)
- `glslc` (for shader compilation - part of Vulkan SDK)

## Project Structure

```
src/
├── main.zig       - Application entry point and main loop
├── c.zig          - Shared SDL3 C bindings
├── gpu.zig        - GPU abstraction layer (Device, Buffer, Shader, Pipeline)
├── renderer.zig   - Rendering logic
└── geometry.zig   - Geometry data (Triangle vertices)

shaders/
├── triangle.vert.glsl  - Vertex shader source (GLSL)
├── triangle.frag.glsl  - Fragment shader source (GLSL)
├── triangle.vert.spv   - Compiled vertex shader (SPIR-V)
└── triangle.frag.spv   - Compiled fragment shader (SPIR-V)
```

## Building

```bash
zig build
```

## Running

```bash
zig build run
```

## Shaders

The GLSL source shaders are in `shaders/`:

- `triangle.vert.glsl` - Vertex shader (transforms vertices and passes color to fragment shader)
- `triangle.frag.glsl` - Fragment shader (outputs interpolated color per pixel)

These are compiled to SPIR-V bytecode which SDL GPU uses for cross-platform compatibility.

### Recompiling Shaders

If you modify the GLSL shaders, recompile them with:

```bash
glslc -fshader-stage=vertex shaders/triangle.vert.glsl -o shaders/triangle.vert.spv
glslc -fshader-stage=fragment shaders/triangle.frag.glsl -o shaders/triangle.frag.spv
```

## What it does

This project demonstrates:

- Creating an SDL3 window and GPU device
- Loading and compiling SPIR-V shaders
- Creating GPU buffers and uploading vertex data
- Building a graphics pipeline with vertex attributes
- Rendering a colored triangle with RGB gradient interpolation
- Clean separation of concerns with modular design

## Architecture

- **GPU Module**: Handles low-level GPU resource management (devices, buffers, shaders, pipelines)
- **Renderer Module**: Encapsulates the render loop and draw commands
- **Geometry Module**: Defines vertex structures and geometry data
- **Main**: Ties everything together with the event loop

## License

MIT
