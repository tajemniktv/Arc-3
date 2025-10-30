export class Options {
    get Material_Format(): number {return getIntSetting('MATERIAL_FORMAT');}

    get Material_Parallax_Enabled(): boolean {return getBoolSetting('MATERIAL_PARALLAX_ENABLED');}
    get Material_Parallax_Type(): number {return getIntSetting('MATERIAL_PARALLAX_TYPE');}
    get Material_Parallax_Depth(): number {return getIntSetting('MATERIAL_PARALLAX_DEPTH');}
    get Material_Parallax_SampleCount(): number {return getIntSetting('MATERIAL_PARALLAX_SAMPLES');}
    get Material_Parallax_Optimize(): boolean {return getBoolSetting('MATERIAL_PARALLAX_OPTIMIZE');}
    get Material_Parallax_BlockEntities(): boolean {return getBoolSetting('MATERIAL_PARALLAX_BLOCKENTITIES');}
    
    get Lighting_ColorCandles(): boolean {return getBoolSetting('LIGHTING_COLOR_CANDLES');}

    get Lighting_Ambient_Brightness(): number {return getFloatSetting('LIGHTING_AMBIENT_BRIGHTNESS');}
    get Lighting_Ambient_Red(): number {return getFloatSetting('LIGHTING_AMBIENT_RED');}
    get Lighting_Ambient_Green(): number {return getFloatSetting('LIGHTING_AMBIENT_GREEN');}
    get Lighting_Ambient_Blue(): number {return getFloatSetting('LIGHTING_AMBIENT_BLUE');}

    get Lighting_Point_Enabled(): boolean {return getBoolSetting('LIGHTING_POINT_ENABLED');}
    get Lighting_Point_EmissionMask(): boolean {return getBoolSetting('LIGHTING_POINT_EMISSION_MASK');}
    get Lighting_Point_MaxCount(): number {return getIntSetting('LIGHTING_POINT_MAXCOUNT');}
    get Lighting_Point_Resolution(): number {return getIntSetting('LIGHTING_POINT_RESOLUTION');}
    get Lighting_Point_RealTime(): number {return getIntSetting('LIGHTING_POINT_REALTIME');}
    get Lighting_Attenuation_Mode(): number {return getIntSetting('LIGHTING_ATTENUATION_MODE');}
    get Lighting_Point_RealTime(): number {return getIntSetting('LIGHTING_POINT_REALTIME');}

    get Shadow_Resolution(): number {return getIntSetting('SHADOW_RESOLUTION');}
    get Shadow_Distance(): number {return getIntSetting('SHADOW_DISTANCE');}
    get Shadow_Angle(): number {return getIntSetting('SHADOW_ANGLE');}

    get Post_Bloom_Enabled(): boolean {return getBoolSetting('POST_BLOOM_ENABLED');}
    get Post_TAA_Enabled(): boolean {return getBoolSetting('POST_TAA_ENABLED');}

    get Debug_Material(): number {return getIntSetting('DEBUG_MATERIAL');}
    get Debug_WhiteWorld(): boolean {return getBoolSetting('DEBUG_WHITEWORLD');}
    get Debug_Histogram(): boolean {return getBoolSetting('DEBUG_HISTOGRAM');}
}
