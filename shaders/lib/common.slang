static const float PI = 3.14159265358;
static const float EPSILON = 1.0e-6;

static const int DEBUG_MAT_ALBEDO = 0;
static const int DEBUG_MAT_NORMAL_GEO = 1;
static const int DEBUG_MAT_NORMAL_TEX = 2;


float minOf(float x, float y, float z) {
    return min(x, min(y, z));
}

float3 minOf(float3 x, float3 y, float3 z) {
    return min(x, min(y, z));
}

float maxOf(float x, float y, float z) {
    return max(x, max(y, z));
}

float3 maxOf(float3 x, float3 y, float3 z) {
    return max(x, max(y, z));
}

float sumOf(const in float3 vec) {
    return vec.x + vec.y + vec.z;
}

float unmix(const in float valueMin, const in float valueMax, const in float value) {
    return (value - valueMin) / (valueMax - valueMin);
}

float3 mul3(const in float4x4 matrix, const in float3 vector) {
    return mul(matrix, float4(vector, 1.0)).xyz;
    // TODO: transpose translation?
    //return mul(vector, float3x3(matrix)) + matrix[3].xyz;
}

// float3 unproject(const in float4 pos) {
//     return pos.xyz / pos.w;
// }

// float3 unproject(const in float4x4 matProj, const in float3 pos) {
//     return unproject(mul(float4(pos, 1.0), matProj));
// }

float3 unproject(const in float4x4 matrix, const in float3 vector) {
    float4 result = mul(matrix, float4(vector, 1.0));
    return result.xyz / result.w;
}

float luminance(const in float3 color) {
    static const float3 L = float3(0.2126, 0.7152, 0.0722);
    return dot(color, L);
}

float3 LinearToRgb(const in float3 color) {
    float3 is_high = step(0.00313066844250063, color);
    float3 higher = 1.055 * pow(color, float3(1.0/2.4)) - 0.055;
    float3 lower = color * 12.92;

    return lerp(lower, higher, is_high);
}

float3 RgbToLinear(const in float3 color) {
    float3 is_high = step(0.0404482362771082, color);
    float3 higher = pow((color + 0.055) / 1.055, float3(2.4));
    float3 lower = color / 12.92;

    return lerp(lower, higher, is_high);
}
