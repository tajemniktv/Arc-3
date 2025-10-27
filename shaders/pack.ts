import {Options} from "./scripts/Options";
import {BufferFlipper} from "./scripts/BufferFlipper";
import {StreamingBufferBuilder} from "./scripts/StreamingBufferBuilder";
import {setLightColorEx} from "./scripts/Helpers";


const options = new Options();
const Scene_PostExposureMin = -0.8;
const Scene_PostExposureMax = 10.8;
const Scene_PostExposureOffset = 0.0;

let texFinalPrevA : BuiltTexture | undefined;
let texFinalPrevB : BuiltTexture | undefined;
let texFinalPrevRef : ActiveTextureReference | undefined;
let imgFinalPrevRef : ActiveTextureReference | undefined;
let settings : BuiltStreamingBuffer | undefined;


export function configureRenderer(config: RendererConfig): void {
    config.sunPathRotation = 20;
    config.ambientOcclusionLevel = 1.0;
    config.mergedHandDepth = true;
    config.disableShade = true;

    config.render.waterOverlay = false;
    config.render.entityShadow = false;
    config.render.vignette = false;
    config.render.horizon = false;
    config.render.clouds = false;
    config.render.stars = false;
    config.render.moon = false;
    config.render.sun = false;

    config.shadow.enabled = true;
    config.shadow.cascades = 4;
    config.shadow.resolution = 1024;
    config.shadow.distance = 200;

    config.pointLight.maxCount = options.Lighting_Point_Enabled ? options.Lighting_Point_MaxCount : 0;
    config.pointLight.resolution = options.Lighting_Point_Resolution;
    config.pointLight.cacheRealTimeTerrain = false;
    config.pointLight.nearPlane = 0.1;
    config.pointLight.farPlane = 16.0;
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

    pipeline.setGlobalExport(pipeline.createExportList()
        .addFloat('BLOCK_LUX', 200)
        .addInt('MATERIAL_FORMAT', options.Material_Format)
        .addBool('PointLight_Enabled', options.Lighting_Point_Enabled)
        .addInt('PointLight_MaxCount', renderConfig.pointLight.maxCount)
        .addBool('TAA_Enabled', options.Post_TAA_Enabled)
        .addBool('Debug_WhiteWorld', options.Debug_WhiteWorld)
        .build());

    setLightColorEx('#8053d1', 'amethyst_cluster');
    setLightColorEx('#3e2d1f', 'brown_mushroom');
    setLightColorEx('#f39849', 'campfire');
    setLightColorEx('#935b2c', 'cave_vines', "cave_vines_plant");
    setLightColorEx('#d39f6d', 'copper_bulb', 'waxed_copper_bulb');
    setLightColorEx('#d39255', 'exposed_copper_bulb', 'waxed_exposed_copper_bulb');
    setLightColorEx('#cf833a', 'weathered_copper_bulb', 'waxed_weathered_copper_bulb');
    setLightColorEx('#87480b', 'oxidized_copper_bulb', 'waxed_oxidized_copper_bulb');
    setLightColorEx('#7f17a8', 'crying_obsidian', 'respawn_anchor');
    setLightColorEx('#371559', 'enchanting_table');
    setLightColorEx('#ac9833', 'end_gateway');
    setLightColorEx('#5f33ac', 'end_portal');
    setLightColorEx('#bea935', 'firefly_bush');
    setLightColorEx('#5f9889', 'glow_lichen');
    setLightColorEx('#d3b178', 'glowstone');
    setLightColorEx('#c2985a', 'jack_o_lantern');
    setLightColorEx('#f39e49', 'lantern');
    setLightColorEx('#b8491c', 'lava', 'magma_block');
    setLightColorEx('#650a5e', 'nether_portal');
    setLightColorEx('#dfac47', 'ochre_froglight');
    setLightColorEx('#e075e8', 'pearlescent_froglight');
    setLightColorEx('#f9321c', 'redstone_torch', 'redstone_wall_torch');
    setLightColorEx('#e0ba42', 'redstone_lamp');
    setLightColorEx('#f9321c', 'redstone_ore', 'deepslate_redstone_ore');
    setLightColorEx('#8bdff8', 'sea_lantern');
    setLightColorEx('#4d9a76', 'sea_pickle');
    setLightColorEx('#918f34', 'shroomlight');
    setLightColorEx('#28aaeb', 'soul_torch', 'soul_wall_torch', 'soul_campfire');
    setLightColorEx('#f3b549', 'torch', 'wall_torch');
    setLightColorEx('#a61914', 'trial_spawner');
    setLightColorEx('#dfb906', 'vault');
    setLightColorEx('#63e53c', 'verdant_froglight');

    setLightColorEx('#df0606', 'mcwlights:red_paper_lamp');
    setLightColorEx('#df4706', 'mcwlights:orange_paper_lamp');
    setLightColorEx('#dfd406', 'mcwlights:yellow_paper_lamp');
    setLightColorEx('#8fdf06', 'mcwlights:lime_paper_lamp');
    setLightColorEx('#06df0a', 'mcwlights:green_paper_lamp');
    setLightColorEx('#06dfa5', 'mcwlights:cyan_paper_lamp');

    setLightColorEx("#322638", "tinted_glass");
    setLightColorEx("#ffffff", "white_stained_glass", "white_stained_glass_pane");
    setLightColorEx("#999999", "light_gray_stained_glass", "light_gray_stained_glass_pane");
    setLightColorEx("#4c4c4c", "gray_stained_glass", "gray_stained_glass_pane");
    setLightColorEx("#191919", "black_stained_glass", "black_stained_glass_pane");
    setLightColorEx("#664c33", "brown_stained_glass", "brown_stained_glass_pane");
    setLightColorEx("#993333", "red_stained_glass", "red_stained_glass_pane");
    setLightColorEx("#d87f33", "orange_stained_glass", "orange_stained_glass_pane");
    setLightColorEx("#e5e533", "yellow_stained_glass", "yellow_stained_glass_pane");

    setLightColorEx("#7fcc19", "lime_stained_glass", "lime_stained_glass_pane");
    setLightColorEx("#667f33", "green_stained_glass", "green_stained_glass_pane");
    setLightColorEx("#4c7f99", "cyan_stained_glass", "cyan_stained_glass_pane");
    setLightColorEx("#6699d8", "light_blue_stained_glass", "light_blue_stained_glass_pane");
    setLightColorEx("#334cb2", "blue_stained_glass", "blue_stained_glass_pane");
    setLightColorEx("#7f3fb2", "purple_stained_glass", "purple_stained_glass_pane");
    setLightColorEx("#b24cd8", "magenta_stained_glass", "magenta_stained_glass_pane");
    setLightColorEx("#f27fa5", "pink_stained_glass", "pink_stained_glass_pane");

    if (options.Lighting_ColorCandles) {
        setLightColorEx("#c07047", "candle");
        setLightColorEx("#ffffff", "white_candle");
        setLightColorEx("#bbbbbb", "light_gray_candle");
        setLightColorEx("#696969", "gray_candle");
        setLightColorEx("#1f1f1f", "black_candle");
        setLightColorEx("#8f5b35", "brown_candle");
        setLightColorEx("#b53129", "red_candle");
        setLightColorEx("#ff8118", "orange_candle");
        setLightColorEx("#ffcc4b", "yellow_candle");
        setLightColorEx("#7bc618", "lime_candle");
        setLightColorEx("#608116", "green_candle");
        setLightColorEx("#129e9d", "cyan_candle");
        setLightColorEx("#29a1d5", "light_blue_candle");
        setLightColorEx("#455abe", "blue_candle");
        setLightColorEx("#832cb4", "purple_candle");
        setLightColorEx("#bd3cb4", "magenta_candle");
        setLightColorEx("#f689ac", "pink_candle");
    }
    else {
        setLightColorEx("#c07047", "candle", "white_candle", "light_gray_candle", "gray_candle", "black_candle",
            "brown_candle", "red_candle", "orange_candle", "yellow_candle", "lime_candle", "green_candle", "cyan_candle",
            "light_blue_candle", "blue_candle", "purple_candle", "magenta_candle", "pink_candle");
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
    if (options.Post_TAA_Enabled) {
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

    const texMatLightGB = pipeline.createTexture('texMatLightGB')
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RG32UI)
        .clearColor(0, 0, 0, 0)
        .build();

    const texShadowColor = pipeline.createArrayTexture('texShadowColor')
        .format(Format.RGBA8)
        .width(renderConfig.shadow.resolution)
        .height(renderConfig.shadow.resolution)
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


    const texDiffuse = pipeline.createImageTexture('texDiffuse', 'imgDiffuse')
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGBA16F)
        .build();

    const texSpecular = pipeline.createImageTexture('texSpecular', 'imgSpecular')
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGBA16F)
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

    if (!options.Debug_Histogram) {
        setup.createCompute('histogram-clear')
            .location('setup/histogram-clear', "clearHistogram")
            .workGroups(1, 1, 1)
            .compile();
    }

    if (WorldHasSky) {
        setup.createComposite('sky-transmit')
            .location('setup/sky-transmit', 'bakeSkyTransmission')
            .target(0, texSkyTransmit)
            .compile();

        setup.createComposite('sky-multi-scatter')
            .location('setup/sky-multi-scatter', 'bakeSkyMultiScattering')
            .target(0, texSkyMultiScatter)
            .compile();
    }

    setup.end();


    const preRender = pipeline.forStage(Stage.PRE_RENDER);

    preRender.createCompute("begin-scene")
        .location("pre/scene-begin", "beginScene")
        .workGroups(1, 1, 1)
        .compile();

    if (WorldHasSky) {
        preRender.createComposite('sky-view')
            .location('pre/sky-view', 'bakeSkyView')
            .target(0, texSkyView)
            .compile();

        preRender.createComposite('sky-irradiance')
            .location('pre/sky-irradiance', 'bakeSkyIrradiance')
            .target(0, texSkyIrradiance)
            .blendFunc(0, Func.SRC_ALPHA, Func.ONE_MINUS_SRC_ALPHA, Func.ONE, Func.ZERO)
            .compile();
    }

    preRender.end();


    function discardShader(name: string, usage: ProgramUsage) {
        pipeline.createObjectShader(name, usage)
            .location('objects/discard').compile();
    }

    pipeline.createObjectShader("shadow-sky", Usage.SHADOW)
        .location('objects/shadow_sky')
        .target(0, texShadowColor)
        .blendOff(0)
        .compile();

    if (options.Lighting_Point_Enabled) {
        pipeline.createObjectShader('shadow-point', Usage.POINT)
            .location("objects/shadow_point")
            .exportBool('EmissionMask', options.Lighting_Point_EmissionMask)
            .compile();
    }
    
    discardShader("sky-discard", Usage.SKYBOX);
    discardShader("sky-texture-discard", Usage.SKY_TEXTURES);
    discardShader("cloud-discard", Usage.CLOUDS);

    const shaderBasicOpaque = pipeline.createObjectShader("basic-opaque", Usage.BASIC)
        .location("objects/opaque")
        .exportBool("disableFog", false)
        .target(0, texAlbedoGB).blendOff(0)//.blendFunc(0, Func.SRC_ALPHA, Func.ONE_MINUS_SRC_ALPHA, Func.ONE, Func.ZERO)
        .target(1, texNormalGB).blendOff(1)
        .target(2, texMatLightGB).blendOff(2);
    if (options.Post_TAA_Enabled) shaderBasicOpaque.target(3, texVelocity).blendOff(3);
    shaderBasicOpaque.compile();

    const shaderBasicTrans = pipeline.createObjectShader("basic-translucent", Usage.TERRAIN_TRANSLUCENT)
        .location("objects/translucent")
        .exportBool("disableFog", false)
        .target(0, texFinalA)
    if (options.Post_TAA_Enabled) shaderBasicTrans.target(1, texVelocity).blendOff(1);
    shaderBasicTrans.compile();
    
    const stagePostOpaque = pipeline.forStage(Stage.PRE_TRANSLUCENT);

    if (WorldHasSky) {
        stagePostOpaque.createComposite("deferred-lighting-sky")
            .location("deferred/lighting-sky", "lightingSky")
            .target(0, texDiffuse)
            .target(1, texSpecular)
            .compile();
    }

    stagePostOpaque.createComposite("deferred-lighting-block")
        .location("deferred/lighting-block", "lightingBlock")
        .target(0, texDiffuse).blendFunc(0, Func.ONE, Func.ONE, Func.ONE, Func.ONE)
        .target(1, texSpecular).blendFunc(1, Func.ONE, Func.ONE, Func.ONE, Func.ONE)
        .compile();

    stagePostOpaque.createCompute("deferred-lighting-block-point")
        .location("deferred/lighting-block-point", "applyPointLights")
        .workGroups(
            Math.ceil(screenWidth / 16.0),
            Math.ceil(screenHeight / 16.0),
            1)
        .compile();

    stagePostOpaque.createComposite("deferred-lighting-final")
        .location("deferred/lighting-final", "lightingFinal")
        .target(0, finalFlipper.getWriteTexture())
        .compile();

    stagePostOpaque.end();

    finalFlipper.flip();

    const postRender = pipeline.forStage(Stage.POST_RENDER);

    if (options.Debug_Histogram) {
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
        .exportBool("DEBUG_HISTOGRAM", options.Debug_Histogram)
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

    if (options.Post_Bloom_Enabled) {
        finalFlipper.flip();

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
                .overrideObject("texSource", i == 0 ? finalFlipper.getReadTextureName() : 'texBloom')
                //.exportInt("TEX_SCALE", Math.pow(2, i))
                //.exportInt("BLOOM_INDEX", i)
                .exportInt("MIP_INDEX", Math.max(i-1, 0))
                .compile();
        }
    
        for (let i = maxLod-1; i >= 0; i--) {
            const bloomUpShader = bloomStage.createComposite(`bloom-up-${i}`)
                .location('post/bloom-up', "applyBloomUp")
                .overrideObject("texSource", finalFlipper.getReadTextureName())
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
    }

    if (options.Post_TAA_Enabled) {
        texFinalPrevRef = pipeline.createTextureReference("texFinalPrev", null, screenWidth, screenHeight, 1, Format.RGBA16F);
        imgFinalPrevRef = pipeline.createTextureReference(null, "imgFinalPrev", screenWidth, screenHeight, 1, Format.RGBA16F);

        finalFlipper.flip();

        postRender.createCompute("taa")
            .location("post/taa", "applyTaa")
            .workGroups(
                Math.ceil(screenWidth / 16),
                Math.ceil(screenHeight / 16),
                1)
            .overrideObject("texSource", finalFlipper.getReadTextureName())
            .overrideObject("imgFinal", finalFlipper.getWriteImageName())
            .compile();
    }

    finalFlipper.flip();

    postRender.createComposite("tonemap")
        .location("post/tonemap", "applyTonemap")
        .target(0, finalFlipper.getWriteTexture())
        .overrideObject("texSource", finalFlipper.getReadTextureName())
        .compile();

    if (options.Post_TAA_Enabled) {
        finalFlipper.flip();

        postRender.createCompute("sharpen")
            .location("post/sharpen", "sharpen")
            .workGroups(
                Math.ceil(screenWidth / 16),
                Math.ceil(screenHeight / 16),
                1)
            .overrideObject("texSource", finalFlipper.getReadTextureName())
            .overrideObject("imgFinal", finalFlipper.getWriteImageName())
            .compile();
    }

    if (options.Debug_Material > 0 || options.Debug_Histogram) {
        postRender.createComposite("debug")
            .location("post/debug", "renderDebugOverlay")
            .target(0, finalFlipper.getWriteTexture())
            .blendFunc(0, Func.SRC_ALPHA, Func.ONE_MINUS_SRC_ALPHA, Func.ONE, Func.ZERO)
            .exportInt('DEBUG_MATERIAL', options.Debug_Material)
            .exportBool('DEBUG_HISTOGRAM', options.Debug_Histogram)
            .exportFloat("Scene_PostExposureMin", Scene_PostExposureMin)
            .exportFloat("Scene_PostExposureMax", Scene_PostExposureMax)
            .compile();
    }

    postRender.end();

    finalFlipper.flip();

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
    if (options.Post_TAA_Enabled) {
        const alt = state.currentFrame() % 2 == 1;
        texFinalPrevRef.pointTo(alt ? texFinalPrevA : texFinalPrevB);
        imgFinalPrevRef.pointTo(alt ? texFinalPrevB : texFinalPrevA);
    }

    settings.uploadData();
}
