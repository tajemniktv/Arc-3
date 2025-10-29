export function setupOptions() {
    return new Page('main')
        .add(new Page('MATERIAL')
            .add(asInt('MATERIAL_FORMAT', 0, 1, 2).needsReload(true).build(0))
            .add(EMPTY)
            .add(new Page("MATERIAL_PARALLAX")
                .add(asBool('MATERIAL_PARALLAX_ENABLED', false, true))
                .add(EMPTY)
                .add(asInt('MATERIAL_PARALLAX_TYPE', 0, 1, 2).needsReload(true).build(2))
                .add(asIntRange('MATERIAL_PARALLAX_DEPTH', 25, 5, 100, 5, true))
                .add(asIntRange('MATERIAL_PARALLAX_SAMPLES', 32, 8, 128, 8, true))
                .add(asBool('MATERIAL_PARALLAX_OPTIMIZE', true, true))
                .build())
            .build())
        .add(new Page('LIGHTING')
            .add(new Page('LIGHTING_POINT')
                .add(asBool('LIGHTING_POINT_ENABLED', true, true))
                .add(asBool('LIGHTING_POINT_EMISSION_MASK', false, true))
                .add(asIntRange('LIGHTING_POINT_MAXCOUNT', 128, 4, 256, 4, true))
                .add(asInt('LIGHTING_POINT_RESOLUTION', 32, 64, 128, 256, 512).needsReload(true).build(128))
                .add(asInt('LIGHTING_ATTENUATION_MODE', 0, 1, 2).needsReload(false).build(1))
                .build())
            .add(EMPTY)
            .add(new Page('LIGHTING_AMBIENT')
                .add(asFloatRange('LIGHTING_AMBIENT_BRIGHTNESS', 0.02, 0.0, 0.5, 0.01, false))
                .add(asFloatRange('LIGHTING_AMBIENT_RED', 1.0, 0.0, 2.0, 0.05, false))
                .add(asFloatRange('LIGHTING_AMBIENT_GREEN', 1.0, 0.0, 2.0, 0.05, false))
                .add(asFloatRange('LIGHTING_AMBIENT_BLUE', 1.0, 0.0, 2.0, 0.05, false))
                .build())
            .add(EMPTY)
            .add(asBool('LIGHTING_COLOR_CANDLES', true, true))
            .build())
        .add(new Page('SHADOWS')
            .add(asInt('SHADOW_RESOLUTION', 512, 1024, 2048, 4096, 8192).needsReload(true).build(1024))
            .add(asInt('SHADOW_DISTANCE', 50, 100, 150, 200, 250, 300, 400, 500, 600, 800, 1000, 2000, 4000, 8000).needsReload(true).build(200))
            .build())
        .add(new Page('POST')
            .add(asBool('POST_BLOOM_ENABLED', true, true))
            .add(asBool('POST_TAA_ENABLED', true, true))
            .build())
        .add(EMPTY)
        .add(new Page('DEBUG')
            .add(asIntRange('DEBUG_MATERIAL', 0, 0, 5, 1, true))
            .add(asBool('DEBUG_WHITEWORLD', false, true))
            .add(asBool('DEBUG_HISTOGRAM', false, true))
            .build())
        .build();
}

function asIntRange(keyName: string, defaultValue: number, valueMin: number, valueMax: number, interval: number, reload: boolean = true) {
    const values = getValueRange(valueMin, valueMax, interval);
    return asInt(keyName, ...values).needsReload(reload).build(defaultValue);
}

function asFloatRange(keyName: string, defaultValue: number, valueMin: number, valueMax: number, interval: number, reload: boolean = true) {
    const values = getValueRange(valueMin, valueMax, interval);
    return asFloat(keyName, ...values).needsReload(reload).build(defaultValue);
}

function asStringRange(keyName: string, defaultValue: number, valueMin: number, valueMax: number, reload: boolean = true) {
    const values = getValueRange(valueMin, valueMax, 1);
    return asString(keyName, ...values.map(v => v.toString())).needsReload(reload).build(defaultValue.toString());
}

function getValueRange(valueMin: number, valueMax: number, interval: number) {
    const values = [];

    let value = valueMin;
    while (value <= valueMax) {
        values.push(value);
        value += interval;
    }

    return values;
}
