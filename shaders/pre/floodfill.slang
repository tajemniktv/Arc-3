import aperture;
import lib.common;
import lib.light.floodfill;
import lib.hsv;


extern static const bool PointLight_Enabled;

static const float LpvFalloff = 0.998;
static const int3 flattenShared = int3(1, 10, 100);
static const float LpvBlockRange = 0.2;

static const int sharedBufferSize = 10*10*10;
groupshared int sharedBlockMap[sharedBufferSize];
groupshared uint sharedBlockMetaMap[sharedBufferSize];
groupshared float3 floodfillBuffer[sharedBufferSize];

[[vk::image_format("rgba16f")]]
RWTexture3D<float4> imgFloodFill_write;

Sampler3D texFloodFill_read;


int getSharedCoord(int3 pos) {
	return sumOf(pos * flattenShared);
}

int3 GetVoxelFrameOffset() {
    // float3 posNow = GetVoxelCenter(ap.camera.position, ap.camera.viewInv[2].xyz);
    // float3 posPrev = GetVoxelCenter(ap.temporal.position, ap.temporal.viewInv[2].xyz);
    float3 posNow = GetVoxelCenter(ap.camera.position);
    float3 posPrev = GetVoxelCenter(ap.temporal.position);

    float3 posLast = fract(posNow) + (ap.temporal.position - posPrev) - (ap.camera.position - posNow);
    return int3(floor(posLast));
}

float3 floodfill_sample_prev(in int3 texCoord) {
	if (!FloodFill_InBounds(texCoord)) return 0.0;

	float3 lpvSample = texFloodFill_read[texCoord].rgb;

	float3 hsv = RgbToHsv(lpvSample);
	hsv.z = exp2(hsv.z * LpvBlockRange) - 1.0;
	lpvSample = HsvToRgb(hsv);

	return lpvSample;
}

void populateShared(ComputeInput input) {
	uint i_base = uint(input.groupIndex) * 2u;
	if (i_base >= 1000u) return;

	int3 workGroupOffset = int3(input.groupPos * WorkgroupSize()) - 1;
	int3 voxelFrameOffset = GetVoxelFrameOffset();

	[ForceUnroll]
	for (int i = 0; i < 2; i++) {
		int x = i_base + i;
	
		int3 bufferPos = workGroupOffset + int3(x / flattenShared) % 10;
		floodfillBuffer[x] = floodfill_sample_prev(bufferPos - voxelFrameOffset);

		uint blockMeta = 0u;
		float3 voxelPos = FloodFill_GetLocalPosition(bufferPos) + ap.camera.position + 0.5;
		int blockId = ap.voxel[int3(floor(voxelPos))].blockId;

		if (blockId >= 0)
			blockMeta = ap.blocks[blockId].metadata;

		sharedBlockMap[x] = blockId;
		sharedBlockMetaMap[x] = blockMeta;
	}
}

float3 sampleFloodfillShared(int3 pos, uint mask_index) {
	int shared_index = getSharedCoord(pos);
//	uint blockMeta = sharedBlockMetaMap[shared_index];
//	uint wMask = bitfieldExtract(blockMeta, int(mask_index), 1);
	return floodfillBuffer[shared_index];// * wMask;
}

float3 mixNeighbours(const in int3 fragCoord, const in uint mask) {
	uint3 m1 = 1u - (uint3(mask) >> uint3(BLOCK_FACE_WEST, BLOCK_FACE_UP, BLOCK_FACE_NORTH)) & 1u;
	uint3 m2 = 1u - (uint3(mask) >> uint3(BLOCK_FACE_EAST, BLOCK_FACE_DOWN, BLOCK_FACE_SOUTH)) & 1u;

	float3 nX1 = sampleFloodfillShared(fragCoord + int3(-1,  0,  0), BLOCK_FACE_EAST) * m1.x;
	float3 nX2 = sampleFloodfillShared(fragCoord + int3( 1,  0,  0), BLOCK_FACE_WEST) * m2.x;
	float3 nY1 = sampleFloodfillShared(fragCoord + int3( 0, -1,  0), BLOCK_FACE_DOWN) * m1.y;
	float3 nY2 = sampleFloodfillShared(fragCoord + int3( 0,  1,  0), BLOCK_FACE_UP) * m2.y;
	float3 nZ1 = sampleFloodfillShared(fragCoord + int3( 0,  0, -1), BLOCK_FACE_SOUTH) * m1.z;
	float3 nZ2 = sampleFloodfillShared(fragCoord + int3( 0,  0,  1), BLOCK_FACE_NORTH) * m2.z;

	const float avgFalloff = (1.0/6.0) * LpvFalloff;
	return (nX1 + nX2 + nY1 + nY2 + nZ1 + nZ2) * avgFalloff;
}


struct ComputeInput {
    uint groupIndex : SV_GroupIndex;
    uint3 groupPos : SV_GroupID;
    uint3 localPos : SV_GroupThreadID;
    uint3 globalPos : SV_DispatchThreadID;
};

[[shader("compute")]]
[numthreads(8, 8, 8)]
void floodfill(ComputeInput input) {
	uint3 chunkPos = input.groupPos * WorkgroupSize();
	if (any(chunkPos >= FloodFill_BufferSize)) return;

	populateShared(input);
	GroupMemoryBarrierWithGroupSync();

	//int3 cellIndex = int3(input.globalPos);
	if (any(input.globalPos >= FloodFill_BufferSize)) return;

	//bool altFrame = ap.timing.frameCounter % 2 == 1;

    //vec3 viewDir = ap.camera.viewInv[2].xyz;
    //vec3 voxelCenter = GetVoxelCenter(ap.camera.pos, viewDir);
    //float3 localPos = FloodFill_GetLocalPosition(input.globalPos + 0.5);

	int3 localCellIndex = int3(input.localPos) + 1;
	int sharedCoord = getSharedCoord(localCellIndex);
	int blockId = sharedBlockMap[sharedCoord];

	bool isFullBlock = false;
	float3 blockTint = 1.0;
	float3 lightColor = 0.0;
	uint lightRange = 0;

	if (blockId > 0) {
		var blockData = ap.blocks[blockId];
		isFullBlock = blockData.isFullBlock;

		//if (blockData.hasTag(TAG_STAIRS)) isFullBlock = true;

		lightColor = blockData.lightColor.rgb;
		lightColor = RgbToLinear(lightColor);

		lightRange = blockData.emission;

		if (lightRange == 0) {
			// TODO: is this reliable?
			blockTint = lightColor;

//				uint meta = sharedBlockMetaMap[sharedCoord];
//				uint blocking = bitfieldExtract(meta, 10, 4);
//				blockTint *= 1.0 - blocking/16.0;
		}

		if (PointLight_Enabled) {
			//if (!iris_hasTag(blockId, TAG_NON_POINT_LIGHT)) lightRange = 0;
			if (lightRange >= 5 && !blockData.isFluid) lightRange = 0;
			// TODO: also enable if out of point volume?
		}
	}

	float3 accumLight = 0.0;

	if (!isFullBlock) {
		uint faceMask = 0u;
		if (blockId > 0u)
			faceMask = sharedBlockMetaMap[sharedCoord];

		accumLight = mixNeighbours(localCellIndex, faceMask) * blockTint;
	}

	if (lightRange > 0) {
		float3 hsv = RgbToHsv(lightColor);
		hsv.z = exp2(lightRange / 15.0) - 1.0;
		accumLight += HsvToRgb(hsv);
	}

	float3 hsv = RgbToHsv(accumLight);
	hsv.z = log2(hsv.z + 1.0) / LpvBlockRange;
	accumLight = HsvToRgb(hsv);

	// accumLight = input.globalPos / float(FloodFill_BufferSize);

	// if (altFrame) imageStore(imgFloodFill_alt, cellIndex, vec4(accumLight, 1.0));
	// else imageStore(imgFloodFill, cellIndex, vec4(accumLight, 1.0));
	imgFloodFill_write[input.globalPos] = float4(accumLight, 1.0);
}
