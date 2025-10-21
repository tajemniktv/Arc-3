export function configureRenderer(renderer: RendererConfig): void {
    renderer.mergedHandDepth = true;
    renderer.ambientOcclusionLevel = 1.0;
    renderer.disableShade = false;
    renderer.render.entityShadow = true;
}

export function configurePipeline(pipeline: PipelineConfig): void {
    const texVelocity = pipeline.createTexture("texVelocity")
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RG16F)
        .build();

    const texFinal = pipeline.createImageTexture("texFinal", "imgFinal")
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGBA16F)
        .build();

    pipeline.createImageTexture("texFinalPrev", "imgFinalPrev")
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGBA16F)
        .clear(false)
        .build();

    pipeline.createBuffer("ssboScene", 8, false);
    //const sceneSettings = pipeline.createStreamingBuffer("sceneSettings", 8);

    const preRender = pipeline.forStage(Stage.PRE_RENDER);

    preRender.createCompute("begin-scene")
        .location("setup/begin_scene", "beginScene")
        .workGroups(1, 1, 1)
        .compile();

    preRender.end();


    pipeline.createObjectShader("basic", Usage.BASIC)
        .location("objects/basic")
        .exportBool("disableFog", false)
        .exportBool("EnableTAA", true)
        .target(0, texFinal)
        .target(1, texVelocity)
        .compile();

    pipeline.createObjectShader("sky", Usage.SKY_TEXTURES)
        .location("objects/basic")
        .exportBool("disableFog", true)
        .exportBool("EnableTAA", true)
        .target(0, texFinal)
        .target(1, texVelocity)
        .compile();


    const postRender = pipeline.forStage(Stage.POST_RENDER);

    postRender.createCompute("taa")
        .location("post/taa", "applyTaa")
        .workGroups(
            Math.ceil(screenWidth / 16),
            Math.ceil(screenHeight / 16),
            1)
        .compile();

    postRender.createComposite("tonemap")
        .location("post/tonemap", "tonemap")
        .target(0, texFinal)
        .compile();

    postRender.createCompute("sharpen")
        .location("post/sharpen", "sharpen")
        .workGroups(
            Math.ceil(screenWidth / 16),
            Math.ceil(screenHeight / 16),
            1)
        .compile();

    postRender.end();

    pipeline.createCombinationPass("post/final").compile();
}

export function beginFrame(state : WorldState) : void {
    // This runs every frame. However, it won't be used in this template.
}
