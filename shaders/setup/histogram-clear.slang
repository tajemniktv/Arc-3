import aperture;

[[vk::image_format("r32ui")]]
RWTexture1D<uint> imgHistogram;


[[shader("compute")]]
[numthreads(256, 1, 1)]
void clearHistogram(uint groupIndex : SV_GroupIndex) {
    imgHistogram[groupIndex] = 0u;
}
