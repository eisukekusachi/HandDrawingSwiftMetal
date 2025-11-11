//
//  Drawing.metal
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

#include <metal_stdlib>
using namespace metal;

struct GrayscalePoint {
    float4 vertices[[ position ]];
    float size[[ point_size ]];
    float alpha;
    float diameterSize;
    float blurSize;
};

vertex GrayscalePoint draw_gray_points_vertex(uint vid[[ vertex_id ]],
                                              constant float2 *position[[ buffer(0) ]],
                                              constant float *grayscale[[ buffer(1) ]],
                                              constant float *diameterSize[[ buffer(2) ]],
                                              constant float *blurSize[[ buffer(3) ]]
                                              ) {
    GrayscalePoint point;
    point.alpha = grayscale[vid];
    point.diameterSize = diameterSize[vid];
    point.blurSize = blurSize[vid];
    point.vertices = float4(position[vid], 0, 1);
    point.size = diameterSize[vid] + (blurSize[vid] * 2);
    return point;
};
fragment float4 draw_gray_points_fragment(GrayscalePoint data [[ stage_in ]],
                                          float2 pointCoord [[ point_coord ]]
                                          ) {
    if (length(pointCoord - float2(0.5)) > 0.5) {
        discard_fragment();
    }

    if (data.blurSize <= 0 ) {
        return float4(data.alpha,
                      data.alpha,
                      data.alpha,
                      1.0);
    } else {
        float distance = length(pointCoord - float2(0.5));
        float radiusPlusBlurSize = data.diameterSize * 0.5 + data.blurSize;
        float blurRatio = data.blurSize / radiusPlusBlurSize;
        float fadeFactor = 1.0 - (distance * 2);

        // The boundaries of the blur become more distinct as the power of squaring increases
        float alpha = data.alpha * pow(min(fadeFactor / blurRatio, 1.0), 3);

        return float4(alpha,
                      alpha,
                      alpha,
                      1.0);
    }
}
