export function setupOptions() {
    return new Page('main')
        .add(new Page('MATERIAL')
            .add(asInt('MATERIAL_FORMAT', 0, 1, 2).needsReload(true).build(0))
            .build())
        .add(new Page('LIGHTING')
            .add(new Page('LIGHTING_POINT')
                .add(asBool('LIGHTING_POINT_ENABLED', true, true))
                .add(asBool('LIGHTING_POINT_EMISSION_MASK', false, true))
                .add(asIntRange('LIGHTING_POINT_MAXCOUNT', 128, 4, 256, 4, true))
                .add(asInt('LIGHTING_POINT_RESOLUTION', 32, 64, 128, 256, 512).needsReload(true).build(128))
                .build())
            .add(EMPTY)
            .add(asBool('LIGHTING_COLOR_CANDLES', true, true))
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
