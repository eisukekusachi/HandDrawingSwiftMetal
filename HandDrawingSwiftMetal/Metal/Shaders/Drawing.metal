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
