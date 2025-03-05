//
//  Texture.metal
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

#include <metal_stdlib>
using namespace metal;

struct TextureData {
    float4 vertices[[ position ]];
    float2 texCoords;
};
vertex TextureData draw_texture_vertex(uint vid[[vertex_id]],
                                       constant float2 *position [[ buffer(0) ]],
                                       constant float2 *texCoords [[ buffer(1) ]]) {
    TextureData data;
    data.vertices = float4(position[vid], 0, 1);
    data.texCoords = texCoords[vid];
    return data;
}
fragment float4 draw_texture_fragment(TextureData data [[ stage_in ]],
                                      texture2d<float> texture [[ texture(0) ]]) {
    constexpr sampler defaultSampler;
    float4 color = texture.sample(defaultSampler, data.texCoords);
    float a = color[3];
    float b = color[2];
    float g = color[1];
    float r = color[0];
    return float4(r, g, b, a);
}

kernel void colorize_grayscale_texture(uint2 gid [[ thread_position_in_grid ]],
                                       constant float4 &rgba [[ buffer(0) ]],
                                       texture2d<float, access::read> srcTexture [[ texture(0) ]],
                                       texture2d<float, access::write> resultTexture [[ texture(1) ]]
                                       ) {
    float4 src = srcTexture.read(gid);

    // The grayscale value is used as the alpha value. The array index can be any of 0 to 2.
    float a = src[0];
    float r = rgba[0] * a;
    float g = rgba[1] * a;
    float b = rgba[2] * a;

    resultTexture.write(float4(r, g, b, a), gid);
}
kernel void merge_textures(uint2 gid [[ thread_position_in_grid ]],
                           texture2d<float, access::read> srcTexture [[ texture(0) ]],
                           texture2d<float, access::read> dstTexture [[ texture(1) ]],
                           texture2d<float, access::write> resultTexture [[ texture(2) ]],
                           constant float &alpha [[ buffer(3) ]]
                           ) {
    float4 src = srcTexture.read(gid);
    float4 dst = dstTexture.read(gid);

    float srcA = src[3] * alpha;
    float srcB = src[2] * alpha;
    float srcG = src[1] * alpha;
    float srcR = src[0] * alpha;
    float dstA = dst[3];
    float dstB = dst[2];
    float dstG = dst[1];
    float dstR = dst[0];
    float r = srcR + dstR * (1 - srcA);
    float g = srcG + dstG * (1 - srcA);
    float b = srcB + dstB * (1 - srcA);
    float a = srcA + dstA * (1 - srcA);

    resultTexture.write(float4(r, g, b, a), gid);
}

kernel void merge_textures_using_masking(uint2 gid [[ thread_position_in_grid ]],
                                         texture2d<float, access::read> srcTexture [[ texture(0) ]],
                                         texture2d<float, access::read> maskingTexture [[ texture(1) ]],
                                         texture2d<float, access::read> dstTexture [[ texture(2) ]],
                                         texture2d<float, access::write> resultTexture [[ texture(3) ]],
                                         constant float &alpha [[ buffer(3) ]]
                                         ) {
    float4 src = srcTexture.read(gid);
    float4 dst = dstTexture.read(gid);
    float4 maskingTexturePixel = maskingTexture.read(gid);

    float srcAlpha = alpha;

    if (maskingTexturePixel[0] == 0.0 && maskingTexturePixel[1] == 0.0 && maskingTexturePixel[2] == 0.0) {
        srcAlpha = 0.0;
    }

    float srcA = src[3] * srcAlpha;
    float srcB = src[2] * srcAlpha;
    float srcG = src[1] * srcAlpha;
    float srcR = src[0] * srcAlpha;
    float dstA = dst[3];
    float dstB = dst[2];
    float dstG = dst[1];
    float dstR = dst[0];
    float r = srcR + dstR * (1 - srcA);
    float g = srcG + dstG * (1 - srcA);
    float b = srcB + dstB * (1 - srcA);
    float a = srcA + dstA * (1 - srcA);

    resultTexture.write(float4(r, g, b, a), gid);
}

kernel void add_color_to_texture(uint2 gid [[ thread_position_in_grid ]],
                                 constant float4 &color [[ buffer(0) ]],
                                 texture2d<float, access::write> resultTexture [[ texture(0) ]]) {
    resultTexture.write(color, gid);
}
