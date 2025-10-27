export class Options {
    get Material_Format(): number {return getIntSetting('MATERIAL_FORMAT');}

    get Lighting_ColorCandles(): boolean {return getBoolSetting('LIGHTING_COLOR_CANDLES');}

    get Lighting_Point_Enabled(): boolean {return getBoolSetting('LIGHTING_POINT_ENABLED');}
    get Lighting_Point_EmissionMask(): boolean {return getBoolSetting('LIGHTING_POINT_EMISSION_MASK');}
    get Lighting_Point_MaxCount(): number {return getIntSetting('LIGHTING_POINT_MAXCOUNT');}
    get Lighting_Point_Resolution(): number {return getIntSetting('LIGHTING_POINT_RESOLUTION');}

    get Post_Bloom_Enabled(): boolean {return getBoolSetting('POST_BLOOM_ENABLED');}
    get Post_TAA_Enabled(): boolean {return getBoolSetting('POST_TAA_ENABLED');}

    get Debug_Material(): number {return getIntSetting('DEBUG_MATERIAL');}
    get Debug_WhiteWorld(): boolean {return getBoolSetting('DEBUG_WHITEWORLD');}
    get Debug_Histogram(): boolean {return getBoolSetting('DEBUG_HISTOGRAM');}
}
