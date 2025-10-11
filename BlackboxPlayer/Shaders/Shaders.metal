//
//  Shaders.metal
//  BlackboxPlayer
//
//  Metal shaders for multi-channel video rendering
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Vertex Shader Structures

/// Vertex input structure
struct VertexIn {
    float2 position [[attribute(0)]];   // Vertex position in clip space
    float2 texCoord [[attribute(1)]];   // Texture coordinate
};

/// Vertex output / Fragment input structure
struct VertexOut {
    float4 position [[position]];       // Clip space position
    float2 texCoord;                    // Texture coordinate passed to fragment shader
};

// MARK: - Vertex Shader

/// Main vertex shader function
/// Transforms vertices and passes texture coordinates to fragment shader
vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
    VertexOut out;

    // Pass through position (already in clip space coordinates)
    out.position = float4(in.position, 0.0, 1.0);

    // Pass through texture coordinates
    out.texCoord = in.texCoord;

    return out;
}

// MARK: - Fragment Shader

/// Main fragment shader function
/// Samples video texture and outputs color
fragment float4 fragment_main(
    VertexOut in [[stage_in]],
    texture2d<float> videoTexture [[texture(0)]],
    sampler textureSampler [[sampler(0)]]
) {
    // Sample the video texture at interpolated texture coordinate
    float4 color = videoTexture.sample(textureSampler, in.texCoord);

    return color;
}
