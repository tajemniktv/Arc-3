import {BufferFlipper} from "./scripts/BufferFlipper";

const ENABLE_TAA = true;
const ENABLE_BLOOM = true;


export function configureRenderer(renderer: RendererConfig): void {
    renderer.ambientOcclusionLevel = 1.0;
    renderer.render.entityShadow = true;
    renderer.mergedHandDepth = true;
    renderer.disableShade = false;
}

export function configurePipeline(pipeline: PipelineConfig): void {
    const texFinalA = pipeline.createImageTexture("texFinalA", "imgFinalA")
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGBA16F)
        .build();

    const texFinalB = pipeline.createImageTexture("texFinalB", "imgFinalB")
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGBA16F)
        .build();

    const finalFlipper = new BufferFlipper(texFinalA, texFinalB);

    let texVelocity : BuiltTexture | undefined;
    if (ENABLE_TAA) {
        pipeline.createImageTexture("texFinalPrev", "imgFinalPrev")
            .width(screenWidth)
            .height(screenHeight)
            .format(Format.RGBA16F)
            .clear(false)
            .build();

        texVelocity = pipeline.createTexture("texVelocity")
            .width(screenWidth)
            .height(screenHeight)
            .format(Format.RG16F)
            .build();
    }

    pipeline.createBuffer("ssboScene", 8, false);
    //const sceneSettings = pipeline.createStreamingBuffer("sceneSettings", 8);

    const preRender = pipeline.forStage(Stage.PRE_RENDER);

    preRender.createCompute("begin-scene")
        .location("setup/begin_scene", "beginScene")
        .workGroups(1, 1, 1)
        .compile();

    preRender.end();


    const shaderSky = pipeline.createObjectShader("sky", Usage.SKY_TEXTURES)
        .location("objects/basic")
        .exportBool("disableFog", true)
        .exportBool("EnableTAA", ENABLE_TAA)
        .target(0, finalFlipper.getWriteTexture());
    if (ENABLE_TAA) shaderSky.target(1, texVelocity);
    shaderSky.compile();

    const shaderBasic = pipeline.createObjectShader("basic", Usage.BASIC)
        .location("objects/basic")
        .exportBool("disableFog", false)
        .exportBool("EnableTAA", ENABLE_TAA)
        .target(0, finalFlipper.getWriteTexture());
    if (ENABLE_TAA) shaderBasic.target(1, texVelocity);
    shaderBasic.compile();
    
    finalFlipper.flip();

    const postRender = pipeline.forStage(Stage.POST_RENDER);

    if (ENABLE_BLOOM) {
        const screenWidth_half = Math.ceil(screenWidth / 2.0);
        const screenHeight_half = Math.ceil(screenHeight / 2.0);
    
        let maxLod = Math.log2(Math.min(screenWidth, screenHeight));
        maxLod = Math.floor(maxLod - 2);
        maxLod = Math.max(Math.min(maxLod, 8), 0);
    
        //print(`Bloom enabled with ${maxLod} LODs`);
    
        const texBloom = pipeline.createTexture('texBloom')
            .format(Format.RGB16F)
            .width(screenWidth_half)
            .height(screenHeight_half)
            .mipmap(true)
            .clear(false)
            .build();
    
        const bloomStage = postRender.subList('Bloom');
    
        for (let i = 0; i < maxLod; i++) {
            bloomStage.createComposite(`bloom-down-${i}`)
                .location("post/bloom-down", "applyBloomDown")
                .target(0, texBloom, i)
                .overrideObject("TEX_SRC", i == 0 ? finalFlipper.getReadTextureName() : 'texBloom')
                //.exportInt("TEX_SCALE", Math.pow(2, i))
                //.exportInt("BLOOM_INDEX", i)
                .exportInt("MIP_INDEX", Math.max(i-1, 0))
                .compile();
        }
    
        for (let i = maxLod-1; i >= 0; i--) {
            const bloomUpShader = bloomStage.createComposite(`bloom-up-${i}`)
                .location('post/bloom-up', "applyBloomUp")
                .overrideObject("TEX_SRC", finalFlipper.getReadTextureName())
                //.exportInt("TEX_SCALE", Math.pow(2, i+1))
                .exportInt("BLOOM_INDEX", i)
                .exportInt("MIP_INDEX", Math.max(i, 0));
                
            if (i == 0) {
                bloomUpShader.target(0, finalFlipper.getWriteTexture())
                    .blendFunc(0, Func.ONE, Func.ZERO, Func.ONE, Func.ZERO);
            }
            else {
                bloomUpShader.target(0, texBloom, i-1)
                    .blendFunc(0, Func.ONE, Func.ONE, Func.ONE, Func.ONE);
            }

            bloomUpShader.compile();
        }
    
        bloomStage.end();

        finalFlipper.flip();
    }

    if (ENABLE_TAA) {
        postRender.createCompute("taa")
            .location("post/taa", "applyTaa")
            .workGroups(
                Math.ceil(screenWidth / 16),
                Math.ceil(screenHeight / 8),
                1)
            .overrideObject("texFinal", finalFlipper.getReadTextureName())
            .overrideObject("imgFinal", finalFlipper.getWriteImageName())
            .compile();

        finalFlipper.flip();
    }

    postRender.createComposite("tonemap")
        .location("post/tonemap", "tonemap")
        .target(0, finalFlipper.getWriteTexture())
        .overrideObject("texFinal", finalFlipper.getReadTextureName())
        .compile();

    finalFlipper.flip();

    if (ENABLE_TAA) {
        postRender.createCompute("sharpen")
            .location("post/sharpen", "sharpen")
            .workGroups(
                Math.ceil(screenWidth / 16),
                Math.ceil(screenHeight / 8),
                1)
            .overrideObject("texFinal", finalFlipper.getReadTextureName())
            .overrideObject("imgFinal", finalFlipper.getWriteImageName())
            .compile();
        
        finalFlipper.flip();
    }

    postRender.end();

    pipeline.createCombinationPass("post/final")
        .overrideObject("texFinal", finalFlipper.getReadTextureName())
        .compile();
}

export function beginFrame(state : WorldState) : void {
    // This runs every frame. However, it won't be used in this template.
}
