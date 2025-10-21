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
