import aperture;

extern static const int FloodFill_BufferSize = 64;
extern static const float FloodFill_FrustumOffsetF = 0.0;//VOXEL_FRUSTUM_OFFSET * 0.01;

static const uint3 FloodFill_BufferCenter = FloodFill_BufferSize / 2;

static const uint BLOCK_FACE_UP = 1;
static const uint BLOCK_FACE_DOWN = 0;
static const uint BLOCK_FACE_NORTH = 2;
static const uint BLOCK_FACE_SOUTH = 3;
static const uint BLOCK_FACE_EAST = 5;
static const uint BLOCK_FACE_WEST = 4;


bool FloodFill_InBounds(const in int3 voxelPos) {
    return all(clamp(voxelPos, 0, FloodFill_BufferSize-1) == voxelPos);
}

bool FloodFill_InBounds(const in float3 voxelPos) {
    return all(clamp(voxelPos, 0.5, FloodFill_BufferSize-0.5) == voxelPos);
}

// float3 GetVoxelCenter(const in float3 viewPos, const in float3 viewDir) {
//     int3 offset = int3(floor(viewDir * FloodFill_BufferCenter * FloodFill_FrustumOffsetF));
//     return (FloodFill_BufferCenter + offset) + fract(viewPos);
// }

float3 GetVoxelCenter(const in float3 viewPos) {
    return FloodFill_BufferCenter + fract(viewPos);
}

float3 FloodFill_GetLocalPosition(const in float3 voxelPos) {
    // return voxelPos - GetVoxelCenter(ap.camera.position, ap.camera.viewInv[2].xyz);
    return voxelPos - GetVoxelCenter(ap.camera.position);
}
