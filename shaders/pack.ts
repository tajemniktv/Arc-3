import {Options} from "./scripts/Options";
import {BufferFlipper} from "./scripts/BufferFlipper";
import {StreamingBufferBuilder} from "./scripts/StreamingBufferBuilder";
import {ApplyLightColors} from "./scripts/Lights";


const options = new Options();
const Scene_PostExposureMin = -0.8;
const Scene_PostExposureMax = 10.8;
const Scene_PostExposureOffset = 0.0;

let texFinalPrevA: BuiltTexture | undefined;
let texFinalPrevB: BuiltTexture | undefined;
let texFinalPrevRef: ActiveTextureReference | undefined;
let imgFinalPrevRef: ActiveTextureReference | undefined;
let settings: BuiltStreamingBuffer | undefined;

let _renderConfig: RendererConfig;


export function configureRenderer(config: RendererConfig): void {
    // HACK: allows realtime settings
    _renderConfig = config;

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
    config.shadow.resolution = options.Shadow_Resolution;
    config.shadow.distance = options.Shadow_Distance;

    config.pointLight.maxCount = options.Lighting_Point_Enabled ? options.Lighting_Point_MaxCount : 0;
    config.pointLight.resolution = options.Lighting_Point_Resolution;
    config.pointLight.realTimeCount = options.Lighting_Point_RealTime;
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
            pipeline.importPNGTexture('texMoon', 'textures/moon.png', true, false);
            break;
    }

    pipeline.setGlobalExport(pipeline.createExportList()
        .addFloat('BLOCK_LUX', 200)
        .addInt('MATERIAL_FORMAT', options.Material_Format)
        .addInt('SHADOW_CASCADE_COUNT', 4)
        .addBool('PointLight_Enabled', options.Lighting_Point_Enabled)
        .addInt('PointLight_MaxCount', renderConfig.pointLight.maxCount)
        .addBool('TAA_Enabled', options.Post_TAA_Enabled)
        .addBool('Debug_WhiteWorld', options.Debug_WhiteWorld)
        .build());

    ApplyLightColors(options.Lighting_ColorCandles);

    pipeline.createBuffer("scene", 1024, false);
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

    const texWeather = pipeline.createTexture('texWeather')
        .width(screenWidth)
        .height(screenHeight)
        .format(Format.RGBA16F)
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

    if (options.Debug_LightTiles) {
        pipeline.createImageTexture('texDebug', 'imgDebug')
            .format(Format.RGBA8)
            .width(screenWidth)
            .height(screenHeight)
            .clear(true)
            .build();
    }


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

    function opaqueObjectShader(name: string, usage: ProgramUsage, parallaxOverride?: boolean) {
        const parallaxEnabled = parallaxOverride !== undefined ? parallaxOverride : options.Material_Parallax_Enabled;
        const shader = pipeline.createObjectShader(name, usage)
            .location("objects/opaque")
            .exportBool('Parallax_Enabled', parallaxEnabled)
            .exportInt('Parallax_Type', options.Material_Parallax_Type)
            // .exportFloat('Parallax_Depth', options.Material_Parallax_Depth * 0.01)
            .exportInt('Parallax_SampleCount', options.Material_Parallax_SampleCount)
            .exportBool('Parallax_Optimize', options.Material_Parallax_Optimize)
            .target(0, texAlbedoGB).blendOff(0)//.blendFunc(0, Func.SRC_ALPHA, Func.ONE_MINUS_SRC_ALPHA, Func.ONE, Func.ZERO)
            .target(1, texNormalGB).blendOff(1)
            .target(2, texMatLightGB).blendOff(2);

        if (options.Post_TAA_Enabled) shader.target(3, texVelocity).blendOff(3);
        return shader;
    }

    opaqueObjectShader("basic-opaque", Usage.BASIC, options.Material_Parallax_Enabled && options.Material_Parallax_BlockEntities)
        .compile();
    
    opaqueObjectShader("terrain-solid", Usage.TERRAIN_SOLID)
        .exportBool('RENDER_TERRAIN', true)
        .compile();

    opaqueObjectShader("terrain-cutout", Usage.TERRAIN_CUTOUT)
        .exportBool('RENDER_TERRAIN', true)
        .compile();

    opaqueObjectShader("entity-solid", Usage.ENTITY_SOLID).compile();
    
    opaqueObjectShader("entity-cutout", Usage.ENTITY_CUTOUT).compile();

    // opaqueObjectShader("basic-opaque", Usage.PARTICLES_TRANSLUCENT)
    //     .exportBool('RENDER_PARTICLES', true)
    //     .compile();

    function translucentObjectShader(name: string, usage: ProgramUsage) {
        const shader = pipeline.createObjectShader(name, usage)
            .location("objects/translucent")
            .target(0, finalFlipper.getWriteTexture()).blendFunc(0, Func.SRC_ALPHA, Func.ONE_MINUS_SRC_ALPHA, Func.ONE, Func.ZERO);

        //if (options.Post_TAA_Enabled) shader.target(1, texVelocity).blendOff(1);
        return shader;
    }

    translucentObjectShader("terrain-translucent", Usage.TERRAIN_TRANSLUCENT)
        .exportBool('RENDER_TERRAIN', true)
        .compile();

    translucentObjectShader("entity-translucent", Usage.ENTITY_TRANSLUCENT).compile();

    translucentObjectShader("particles", Usage.PARTICLES)
        .exportBool('RENDER_PARTICLES', true)
        .compile();

    pipeline.createObjectShader("weather", Usage.WEATHER)
        .location("objects/weather")
        .target(0, texWeather).blendFunc(0, Func.SRC_ALPHA, Func.ONE_MINUS_SRC_ALPHA, Func.ONE, Func.ZERO)
        .compile();
        
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
        .exportBool('DEBUG_LIGHT_TILES', options.Debug_LightTiles)
        .exportInt("LIGHTING_ATTENUATION_MODE", options.Lighting_Attenuation_Mode)
        .compile();

    stagePostOpaque.createComposite("deferred-lighting-final")
        .location("deferred/lighting-final", "lightingFinal")
        .target(0, finalFlipper.getWriteTexture())
        .exportFloat("Lighting_Ambient_Brightness", options.Lighting_Ambient_Brightness)
        .exportFloat("Lighting_Ambient_Red", options.Lighting_Ambient_Red)
        .exportFloat("Lighting_Ambient_Green", options.Lighting_Ambient_Green)
        .exportFloat("Lighting_Ambient_Blue", options.Lighting_Ambient_Blue)
        .compile();

    stagePostOpaque.end();

    finalFlipper.flip();

    const postRender = pipeline.forStage(Stage.POST_RENDER);

    //finalFlipper.flip();

    postRender.createComposite("composite-overlays")
        .location("composite/overlays", "applyOverlays")
        .target(0, finalFlipper.getReadTexture())
        .overrideObject('texSource', finalFlipper.getReadTexture().name())
        .compile();

    // finalFlipper.flip();
        
    if (options.Debug_Histogram) {
        postRender.createCompute('histogram-clear')
            .location('setup/histogram-clear', "clearHistogram")
            .workGroups(1, 1, 1)
            .compile();
    }

    postRender.createCompute('histogram')
        .location('post/histogram-exposure', "buildHistogram")
        .workGroups(
            Math.ceil(screenWidth / 16.0),
            Math.ceil(screenHeight / 16.0),
            1)
        .overrideObject('texSource', finalFlipper.getReadTexture().name())
        .exportFloat("Scene_PostExposureMin", Scene_PostExposureMin)
        .exportFloat("Scene_PostExposureMax", Scene_PostExposureMax)
        .compile();

    postRender.createCompute('exposure-compute')
        .location('post/histogram-exposure', "computeExposure")
        .workGroups(1, 1, 1)
        .exportBool("DEBUG_HISTOGRAM", options.Debug_Histogram)
        .exportFloat("Scene_PostExposureMin", Scene_PostExposureMin)
        .exportFloat("Scene_PostExposureMax", Scene_PostExposureMax)
        .compile();

    postRender.createComposite("exposure-apply")
        .location("post/expose", "applyExposure")
        .target(0, finalFlipper.getWriteTexture())
        .overrideObject("texSource", finalFlipper.getReadTexture().name())
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
                .location("post/bloom", "applyBloomDown")
                .target(0, texBloom, i)
                .overrideObject("texSource", i == 0 ? finalFlipper.getReadTexture().name() : 'texBloom')
                //.exportInt("TEX_SCALE", Math.pow(2, i))
                //.exportInt("BLOOM_INDEX", i)
                .exportInt("MIP_INDEX", Math.max(i-1, 0))
                .compile();
        }
    
        for (let i = maxLod-1; i >= 0; i--) {
            const bloomUpShader = bloomStage.createComposite(`bloom-up-${i}`)
                .location('post/bloom', "applyBloomUp")
                .overrideObject("texSource", finalFlipper.getReadTexture().name())
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
            .overrideObject("texSource", finalFlipper.getReadTexture().name())
            .overrideObject("imgFinal", finalFlipper.getWriteTexture().imageName())
            .compile();
    }

    finalFlipper.flip();

    postRender.createComposite("tonemap")
        .location("post/tonemap", "applyTonemap")
        .target(0, finalFlipper.getWriteTexture())
        .overrideObject("texSource", finalFlipper.getReadTexture().name())
        .compile();

    if (options.Post_TAA_Enabled) {
        finalFlipper.flip();

        postRender.createCompute("sharpen")
            .location("post/sharpen", "sharpen")
            .workGroups(
                Math.ceil(screenWidth / 16),
                Math.ceil(screenHeight / 16),
                1)
            .overrideObject("texSource", finalFlipper.getReadTexture().name())
            .overrideObject("imgFinal", finalFlipper.getWriteTexture().imageName())
            .compile();
    }

    if (options.Debug_Material > 0 || options.Debug_Histogram || options.Debug_LightTiles) {
        postRender.createComposite("debug")
            .location("post/debug", "renderDebugOverlay")
            .target(0, finalFlipper.getWriteTexture())
            .blendFunc(0, Func.SRC_ALPHA, Func.ONE_MINUS_SRC_ALPHA, Func.ONE, Func.ZERO)
            .exportInt('DEBUG_MATERIAL', options.Debug_Material)
            .exportBool('DEBUG_HISTOGRAM', options.Debug_Histogram)
            .exportBool('DEBUG_LIGHT_TILES', options.Debug_LightTiles)
            .exportFloat("Scene_PostExposureMin", Scene_PostExposureMin)
            .exportFloat("Scene_PostExposureMax", Scene_PostExposureMax)
            .compile();
    }

    postRender.end();

    finalFlipper.flip();

    pipeline.createCombinationPass("post/final")
        .overrideObject("texFinal", finalFlipper.getReadTexture().name())
        .compile();
}

export function onSettingsChanged(pipeline: PipelineConfig) {
    const SkyFogSeaLevel = 60.0;

    _renderConfig.sunPathRotation = options.Shadow_Angle;

    new StreamingBufferBuilder(settings)
        .appendFloat(SkyFogSeaLevel)
        .appendFloat(options.Material_Parallax_Depth * 0.01);
}

export function beginFrame(state : WorldState) : void {
    if (options.Post_TAA_Enabled && texFinalPrevRef && imgFinalPrevRef) {
        // Only runs when TAA is enabled AND references exist
        const alt = state.currentFrame() % 2 == 1;
        texFinalPrevRef.pointTo(alt ? texFinalPrevA : texFinalPrevB);
        imgFinalPrevRef.pointTo(alt ? texFinalPrevB : texFinalPrevA);
    }

    settings.uploadData();
}
