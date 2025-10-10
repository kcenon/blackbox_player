//
//  MultiChannelShaders.metal
//  BlackboxPlayer
//
//  Metal shaders for multi-channel video rendering
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Vertex Shader

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    return out;
}

// MARK: - Fragment Shader

fragment float4 fragment_main(
    VertexOut in [[stage_in]],
    texture2d<float> colorTexture [[texture(0)]]
) {
    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear,
        address::clamp_to_edge
    );

    // Sample the texture
    float4 color = colorTexture.sample(textureSampler, in.texCoord);
    return color;
}

// MARK: - YUV to RGB Conversion (for future use)

fragment float4 fragment_yuv_to_rgb(
    VertexOut in [[stage_in]],
    texture2d<float> yTexture [[texture(0)]],
    texture2d<float> uvTexture [[texture(1)]]
) {
    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear,
        address::clamp_to_edge
    );

    float3 yuv;
    yuv.x = yTexture.sample(textureSampler, in.texCoord).r;
    yuv.yz = uvTexture.sample(textureSampler, in.texCoord).rg - float2(0.5, 0.5);

    // BT.709 conversion matrix
    float3x3 yuvToRGBMatrix = float3x3(
        float3(1.0, 1.0, 1.0),
        float3(0.0, -0.18732, 1.8556),
        float3(1.5748, -0.46812, 0.0)
    );

    float3 rgb = yuvToRGBMatrix * yuv;
    return float4(rgb, 1.0);
}
