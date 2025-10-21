const ENABLE_TAA = false;


export function configureRenderer(renderer: RendererConfig): void {
    renderer.ambientOcclusionLevel = 1.0;
    renderer.render.entityShadow = true;
    renderer.mergedHandDepth = true;
    renderer.disableShade = false;
}

export function configurePipeline(pipeline: PipelineConfig): void {
    const texFinal = pipeline.createImageTexture("texFinal", "imgFinal")
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGBA16F)
        .build();

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
        .target(0, texFinal);
    if (ENABLE_TAA) shaderSky.target(1, texVelocity);
    shaderSky.compile();

    const shaderBasic = pipeline.createObjectShader("basic", Usage.BASIC)
        .location("objects/basic")
        .exportBool("disableFog", false)
        .exportBool("EnableTAA", ENABLE_TAA)
        .target(0, texFinal);
    if (ENABLE_TAA) shaderBasic.target(1, texVelocity);
    shaderBasic.compile();
    

    const postRender = pipeline.forStage(Stage.POST_RENDER);

    if (ENABLE_TAA) {
        postRender.createCompute("taa")
            .location("post/taa", "applyTaa")
            .workGroups(
                Math.ceil(screenWidth / 16),
                Math.ceil(screenHeight / 8),
                1)
            .compile();
    }

    postRender.createComposite("tonemap")
        .location("post/tonemap", "tonemap")
        .target(0, texFinal)
        .compile();

    if (ENABLE_TAA) {
        postRender.createCompute("sharpen")
            .location("post/sharpen", "sharpen")
            .workGroups(
                Math.ceil(screenWidth / 16),
                Math.ceil(screenHeight / 8),
                1)
            .compile();
    }

    postRender.end();

    pipeline.createCombinationPass("post/final").compile();
}

export function beginFrame(state : WorldState) : void {
    // This runs every frame. However, it won't be used in this template.
}
