//
//  Drawing.metal
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

#include <metal_stdlib>
using namespace metal;

struct ColorPoint {
    float4 vertices[[ position ]];
    float size[[ point_size ]];
    float diameterPlusBlurSize;
    float4 color;
    float alpha;
    float blur;
};

vertex ColorPoint draw_gray_points_vertex(uint vid[[ vertex_id ]],
                                          constant float2 *position[[ buffer(0) ]],
                                          constant float *diameterPlusBlurSize[[ buffer(1) ]],
                                          constant float *grayscale[[ buffer(2) ]],
                                          constant float *blurSize[[ buffer(3) ]]
                                          ) {
    ColorPoint point;
    point.vertices = float4(position[vid], 0, 1);
    point.diameterPlusBlurSize = diameterPlusBlurSize[vid];
    point.size = diameterPlusBlurSize[vid];
    point.alpha = grayscale[vid];
    point.blur = blurSize[vid];
    return point;
};
fragment float4 draw_gray_points_fragment(ColorPoint data [[ stage_in ]],
                                          float2 pointCoord [[ point_coord ]]
                                          ) {
    if (length(pointCoord - float2(0.5)) > 0.5) {
        discard_fragment();
    }
    float dist = length(pointCoord - float2(0.5));
    float radiusPlusBlurSize = data.diameterPlusBlurSize * 0.5;
    float blurRatio = data.blur / radiusPlusBlurSize;
    float x = 1.0 - (dist * 2);
    float alpha = data.alpha * pow(min(x / blurRatio, 1.0), 3);
    return float4(alpha,
                  alpha,
                  alpha,
                  1.0);
}

vertex ColorPoint draw_gray_points_vertex2(uint vid[[ vertex_id ]],
                                           constant float2 *position[[ buffer(0) ]],
                                           constant float *diameterPlusBlurSize[[ buffer(1) ]],
                                           constant float *grayscale[[ buffer(2) ]]) {
    ColorPoint point;
    point.vertices = float4(position[vid], 0, 1);
    point.diameterPlusBlurSize = diameterPlusBlurSize[vid];
    point.size = diameterPlusBlurSize[vid];
    point.alpha = grayscale[vid];
    return point;
};
fragment float4 draw_gray_points_fragment2(ColorPoint data [[ stage_in ]],
                                           float2 pointCoord [[ point_coord ]],
                                           constant float &blur[[ buffer(0) ]]) {
    if (length(pointCoord - float2(0.5)) > 0.5) {
        discard_fragment();
    }
    float dist = length(pointCoord - float2(0.5));
    float radiusPlusBlurSize = data.diameterPlusBlurSize * 0.5;
    float blurRatio = blur / radiusPlusBlurSize;
    float x = 1.0 - (dist * 2);
    float alpha = data.alpha * pow(min(x / blurRatio, 1.0), 3);
    return float4(alpha,
                  alpha,
                  alpha,
                  1.0);
}
kernel void colorize_grayscale_texture(uint2 gid [[ thread_position_in_grid ]],
                                       constant float4 &rgba [[ buffer(0) ]],
                                       texture2d<float, access::write> resultTexture [[ texture(0) ]],
                                       texture2d<float, access::read> srcTexture [[ texture(1) ]]) {
    float4 src = srcTexture.read(gid);
    float a = src[0];
    float r = rgba[0] * a;
    float g = rgba[1] * a;
    float b = rgba[2] * a;
    resultTexture.write(float4(r, g, b, a), gid);
}
kernel void merge_textures(uint2 gid [[ thread_position_in_grid ]],
                           texture2d<float, access::write> resultTexture [[ texture(0) ]],
                           texture2d<float, access::read> dstTexture [[ texture(1) ]],
                           texture2d<float, access::read> srcTexture [[ texture(2) ]],
                           constant float &alpha [[ buffer(3) ]]) {
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
kernel void add_color_to_texture(uint2 gid [[ thread_position_in_grid ]],
                                 constant float4 &color [[ buffer(0) ]],
                                 texture2d<float, access::write> resultTexture [[ texture(0) ]]) {
    resultTexture.write(color, gid);
}
kernel void copy_texture(uint2 gid [[ thread_position_in_grid ]],
                         texture2d<float, access::write> resultTexture [[ texture(0) ]],
                         texture2d<float, access::read> srcTexture [[ texture(1) ]]) {
    float4 srcColor = srcTexture.read(gid);
    resultTexture.write(srcColor, gid);
}
