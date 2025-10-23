import {BufferFlipper} from "./scripts/BufferFlipper";
import {StreamingBufferBuilder} from "./scripts/StreamingBufferBuilder";

const ENABLE_TAA = true;
const ENABLE_BLOOM = false;
const DEBUG_HISTOGRAM = true;

const Scene_PostExposureMin = -0.8;
const Scene_PostExposureMax = 2.8;
const Scene_PostExposureOffset = 0.0;

let texFinalPrevA : BuiltTexture | undefined;
let texFinalPrevB : BuiltTexture | undefined;
let texFinalPrevRef : ActiveTextureReference | undefined;
let imgFinalPrevRef : ActiveTextureReference | undefined;
let settings : BuiltStreamingBuffer | undefined;


export function configureRenderer(renderer: RendererConfig): void {
    renderer.ambientOcclusionLevel = 1.0;
    renderer.render.entityShadow = false;
    renderer.render.clouds = false;
    renderer.mergedHandDepth = true;
    renderer.disableShade = true;
}

export function configurePipeline(pipeline: PipelineConfig): void {
    const renderConfig = pipeline.getRendererConfig();

    let WorldHasSky = false;

    switch (renderConfig.dimension.getPath()) {
        case 'the_nether':
            break;
        case 'the_end':
            WorldHasSky = true;
            break;
        default:
            WorldHasSky = true;
            break;
    }

    pipeline.createBuffer("scene", 96, false);
    settings = pipeline.createStreamingBuffer("settings", 32);

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
        texFinalPrevA = pipeline.createImageTexture("texFinalPrevA", "imgFinalPrevA")
            .width(screenWidth)
            .height(screenHeight)
            .format(Format.RGBA16F)
            .clear(false)
            .build();

        texFinalPrevB = pipeline.createImageTexture("texFinalPrevB", "imgFinalPrevB")
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

    const texAlbedoGB = pipeline.createTexture('texAlbedoGB')
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGBA8)
        .clearColor(0, 0, 0, 0)
        .build();

    const texNormalGB = pipeline.createTexture('texNormalGB')
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RG32UI)
        .clearColor(0, 0, 0, 0)
        .build();

    let texSkyTransmit : BuiltTexture | undefined;
    let texSkyMultiScatter : BuiltTexture | undefined;
    let texSkyView : BuiltTexture | undefined;
    let texSkyIrradiance : BuiltTexture | undefined;
    
    if (WorldHasSky) {
        texSkyTransmit = pipeline.createTexture('texSkyTransmit')
            .format(Format.RGB16F)
            .width(256)
            .height(64)
            .clear(false)
            .build();

        texSkyMultiScatter = pipeline.createTexture('texSkyMultiScatter')
            .format(Format.RGB16F)
            .width(32)
            .height(32)
            .clear(false)
            .build();

        texSkyView = pipeline.createTexture('texSkyView')
            .format(Format.RGB16F)
            .width(256)
            .height(256)
            .clear(false)
            .build();

        texSkyIrradiance = pipeline.createTexture('texSkyIrradiance')
            .format(Format.RGB16F)
            .width(32)
            .height(32)
            .clear(false)
            .build();
    }


    const texDiffuse = pipeline.createTexture('texDiffuse')
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGB16F)
        .build();

    const texSpecular = pipeline.createTexture('texSpecular')
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGB16F)
        .build();

    pipeline.createImageTexture('texHistogram', 'imgHistogram')
        .format(Format.R32UI)
        .width(256)
        //.height(1)
        .clear(false)
        .build();


    const setup = pipeline.forStage(Stage.SCREEN_SETUP);

    setup.createCompute("setup-scene")
        .location("setup/scene-setup", "setupScene")
        .workGroups(1, 1, 1)
        .compile();

    if (!DEBUG_HISTOGRAM) {
        setup.createCompute('histogram-clear')
            .location('setup/histogram-clear', "clearHistogram")
            .workGroups(1, 1, 1)
            .compile();
    }

    setup.createComposite('sky-transmit')
        .location('setup/sky-transmit', 'bakeSkyTransmission')
        .target(0, texSkyTransmit)
        .compile();

    setup.createComposite('sky-multi-scatter')
        .location('setup/sky-multi-scatter', 'bakeSkyMultiScattering')
        .target(0, texSkyMultiScatter)
        .compile();

    setup.end();


    const preRender = pipeline.forStage(Stage.PRE_RENDER);

    preRender.createCompute("begin-scene")
        .location("pre/scene-begin", "beginScene")
        .workGroups(1, 1, 1)
        .compile();

    //if (internal.WorldHasSky) {
        preRender.createComposite('sky-view')
            .location('pre/sky-view', 'bakeSkyView')
            .target(0, texSkyView)
            .compile();

        preRender.createComposite('sky-irradiance')
            .location('pre/sky-irradiance', 'bakeSkyIrradiance')
            .target(0, texSkyIrradiance)
            .blendFunc(0, Func.SRC_ALPHA, Func.ONE_MINUS_SRC_ALPHA, Func.ONE, Func.ZERO)
            .compile();
    //}

    preRender.end();


    function discardShader(name: string, usage: ProgramUsage) {
        pipeline.createObjectShader(name, usage)
            .location('objects/discard').compile();
    }

    discardShader("sky-discard", Usage.SKYBOX);
    discardShader("sky-texture-discard", Usage.SKY_TEXTURES);
    discardShader("cloud-discard", Usage.CLOUDS);

    const shaderBasicOpaque = pipeline.createObjectShader("basic-opaque", Usage.BASIC)
        .location("objects/opaque")
        .exportBool("disableFog", false)
        .exportBool("EnableTAA", ENABLE_TAA)
        .target(0, texAlbedoGB)
        .target(1, texNormalGB);
    if (ENABLE_TAA) shaderBasicOpaque.target(2, texVelocity);
    shaderBasicOpaque.compile();

    const shaderBasicTrans = pipeline.createObjectShader("basic-translucent", Usage.TERRAIN_TRANSLUCENT)
        .location("objects/translucent")
        .exportBool("disableFog", false)
        .exportBool("EnableTAA", ENABLE_TAA)
        .target(0, texFinalA)
    if (ENABLE_TAA) shaderBasicTrans.target(1, texVelocity);
    shaderBasicTrans.compile();
    
    const stagePostOpaque = pipeline.forStage(Stage.PRE_TRANSLUCENT);

    stagePostOpaque.createComposite("deferred-lighting-sky")
        .location("deferred/lighting-sky", "lightingSky")
        .target(0, texDiffuse)
        .target(1, texSpecular)
        .compile();

    stagePostOpaque.createComposite("deferred-lighting-final")
        .location("deferred/lighting-final", "lightingFinal")
        .target(0, finalFlipper.getWriteTexture())
        .compile();

    //finalFlipper.flip();

    stagePostOpaque.end();


    const postRender = pipeline.forStage(Stage.POST_RENDER);

    finalFlipper.flip();

    if (DEBUG_HISTOGRAM) {
        postRender.createCompute('histogram-clear')
            .location('setup/histogram-clear', "clearHistogram")
            .workGroups(1, 1, 1)
            .compile();
    }

    postRender.createCompute('histogram')
        .location('post/histogram', "computeHistogram")
        .workGroups(
            Math.ceil(screenWidth / 16.0),
            Math.ceil(screenHeight / 16.0),
            1)
        .overrideObject('texSource', finalFlipper.getReadTextureName())
        .exportFloat("Scene_PostExposureMin", Scene_PostExposureMin)
        .exportFloat("Scene_PostExposureMax", Scene_PostExposureMax)
        .compile();

    postRender.createCompute('exposure-compute')
        .location('post/exposure-compute', "computeExposure")
        .workGroups(1, 1, 1)
        .exportBool("DEBUG_HISTOGRAM", DEBUG_HISTOGRAM)
        .exportFloat("Scene_PostExposureMin", Scene_PostExposureMin)
        .exportFloat("Scene_PostExposureMax", Scene_PostExposureMax)
        .compile();

    postRender.createComposite("exposure-apply")
        .location("post/exposure-apply", "applyExposure")
        .target(0, finalFlipper.getWriteTexture())
        .overrideObject("texSource", finalFlipper.getReadTextureName())
        .exportFloat("Scene_PostExposureMin", Scene_PostExposureMin)
        .exportFloat("Scene_PostExposureMax", Scene_PostExposureMax)
        .exportFloat("Scene_PostExposureOffset", Scene_PostExposureOffset)
        .compile();

    finalFlipper.flip();

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
        texFinalPrevRef = pipeline.createTextureReference("texFinalPrev", null, screenWidth, screenHeight, 1, Format.RGBA16F);
        imgFinalPrevRef = pipeline.createTextureReference(null, "imgFinalPrev", screenWidth, screenHeight, 1, Format.RGBA16F);

        postRender.createCompute("taa")
            .location("post/taa", "applyTaa")
            .workGroups(
                Math.ceil(screenWidth / 16),
                Math.ceil(screenHeight / 8),
                1)
            .overrideObject("texSource", finalFlipper.getReadTextureName())
            .overrideObject("imgFinal", finalFlipper.getWriteImageName())
            .compile();

        finalFlipper.flip();
    }

    postRender.createComposite("tonemap")
        .location("post/tonemap", "applyTonemap")
        .target(0, finalFlipper.getWriteTexture())
        .overrideObject("texSource", finalFlipper.getReadTextureName())
        .compile();

    finalFlipper.flip();

    if (ENABLE_TAA) {
        postRender.createCompute("sharpen")
            .location("post/sharpen", "sharpen")
            .workGroups(
                Math.ceil(screenWidth / 16),
                Math.ceil(screenHeight / 8),
                1)
            .overrideObject("texSource", finalFlipper.getReadTextureName())
            .overrideObject("imgFinal", finalFlipper.getWriteImageName())
            .compile();
        
        finalFlipper.flip();
    }

    if (DEBUG_HISTOGRAM) {
        postRender.createComposite("debug")
            .location("post/debug", "renderDebugOverlay")
            .target(0, finalFlipper.getWriteTexture())
            .blendFunc(0, Func.SRC_ALPHA, Func.ONE_MINUS_SRC_ALPHA, Func.ONE, Func.ZERO)
            .exportFloat("Scene_PostExposureMin", Scene_PostExposureMin)
            .exportFloat("Scene_PostExposureMax", Scene_PostExposureMax)
            .compile();
        
        finalFlipper.flip();
    }

    postRender.end();

    pipeline.createCombinationPass("post/final")
        .overrideObject("texFinal", finalFlipper.getReadTextureName())
        .compile();
}

export function onSettingsChanged(pipeline: PipelineConfig) {
    const SkyFogSeaLevel = 60.0;

    new StreamingBufferBuilder(settings)
        .appendFloat(SkyFogSeaLevel);
}

export function beginFrame(state : WorldState) : void {
    const alt = state.currentFrame() % 2 == 1;
    texFinalPrevRef.pointTo(alt ? texFinalPrevA : texFinalPrevB);
    imgFinalPrevRef.pointTo(alt ? texFinalPrevB : texFinalPrevA);

    settings.uploadData();
}
