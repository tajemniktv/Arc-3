// This configures basic settings for the world.
export function configureRenderer(renderer: RendererConfig): void {
    // These settings mimic Vanilla Minecraft's rendering settings.
    // mergedHandDepth is used to avoid needing to merge the hand depth; however, you will likely want this off for more complex shaders.
    renderer.mergedHandDepth = true;
    renderer.ambientOcclusionLevel = 1.0;
    renderer.disableShade = false;
    renderer.render.entityShadow = true;
}

// This is where the shaders, buffers, and textures are configured.
export function configurePipeline(pipeline: PipelineConfig): void {
    // This creates the main texture; one of the two textures used in this template. It can be accessed via "Sampler2D mainTexture;" in shaders.
    // However, you are not limited by how many textures can be created.
    // The most important limitation is you should never read and write to the same texture in the same shader. (Using images avoids this limitation, but this is not covered here.)

    const texSource = pipeline.createTexture("texSource")
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGBA8)
        .build();

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

    const texFinalPrev = pipeline.createImageTexture("texFinalPrev", "imgFinalPrev")
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGBA16F)
        .clear(false)
        .build();

    let ssboScene = pipeline.createBuffer("ssboScene", 8, false);
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
        .target(0, texSource)
        .target(1, texVelocity)
        .compile();

    pipeline.createObjectShader("sky", Usage.SKY_TEXTURES)
        .location("objects/basic")
        .exportBool("disableFog", true)
        .exportBool("EnableTAA", true)
        .target(0, texSource)
        .target(1, texVelocity)
        .compile();


    const postRender = pipeline.forStage(Stage.POST_RENDER);

    postRender.createComposite("copyToFinal")
        .location("post/copyToFinal", "copyToFinal")
        .target(0, texFinal)
        .compile();

    postRender.createCompute("taa")
        .location("post/taa", "applyTaa")
        .workGroups(
            Math.ceil(screenWidth / 16),
            Math.ceil(screenHeight / 16),
            1)
        .compile();

    postRender.createComposite("tonemap")
        .location("post/tonemap", "applyTonemap")
        .target(0, texFinal)
        .compile();

    // postRender.createComposite("taa-cas")
    //     .location("post/taa-cas", "sharpenTaa")
    //     .target(0, finalTexture)
    //     .compile();

    postRender.end();

    pipeline.createCombinationPass("post/combination").compile();
}

export function beginFrame(state : WorldState) : void {
    // This runs every frame. However, it won't be used in this template.
}
