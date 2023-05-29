// For most passes, these are the flag bits. For the liquid pass, the wind mode bits are used differently

// Bit 0..7
const int GlowLevelBitMask = 0xFF;

// Bit 8..10
const int ZOffsetBitMask = 0x7 << 8;

// Bit 11
const int ReflectiveBitMask = 1 << 11;

// Bit 12
const int Lod0BitMask = 1 << 12;

// Bit 13..25
const int NormalBitMask = 0xFFF << 13;

// Bit 25..28
const int WindModeBitMask = 0xF << 25;

const int WindModePostion = 25;

// Bit 25..28
const int LiquidWaterModeBitMask = 0xF << 25;

// Bit 29
const int LiquidExposedToSkyBitMask = 1 << 29;

// Bit 29..31
const int WindDataBitMask = 0x7 << 29;

const int WindDataPosition = 29;

// Bit 26..31
const int WindBitsMask = WindModeBitMask | WindDataBitMask;


const int WindModeWeakMask = 1 << 25;
const int WindModeNormalMask = 2 << 25;
const int WindModeLeavesMask = 3 << 25;
const int WindModeBendMask = 4 << 25;
const int WindModeTallBendMask = 5 << 25;
const int WindModeWaterMask = 6 << 25;
const int WindModeExtraWeakMask = 7 << 25;
const int WindModeFruitMask = 8 << 25;
const int WindModeWeakWindNoBendMask = 9 << 25;
const int WindModeWeakWindInversedBendMask = 10 << 25;


// We use the wind data bits as the reflective mode. This value is the shape element face Reflective mode minus 1
// This unfortunately means we can't have something reflective *and* wind affected
const int ReflectiveModeWeak = 0;
const int ReflectiveModeMedium = 1;
const int ReflectiveModeStrong = 2;
const int ReflectiveModeSparkly = 3;
const int ReflectiveModeMild = 4;




vec3 unpackNormal(int flags) {
	int x = (flags >> (13+1)) & 0x7;
	int y = (flags >> (13+5)) & 0x7;
	int z = (flags >> (13+9)) & 0x7;
	
	int signx = (flags >> 12) & 2;
	int signy = (flags >> (12+4)) & 2;
	int signz = (flags >> (12+8)) & 2;
	
	return normalize(vec3(
		(1.0 - signx) * x / 7.0,
		(1.0 - signy) * y / 7.0,
		(1.0 - signz) * z / 7.0
	));
}