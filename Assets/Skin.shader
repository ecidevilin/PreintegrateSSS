Shader "Chaos/Skin"
{
	Properties
	{
		_Color("Main Color (Use alpha to blend)", Color) = (1,1,1,1)
		_MainTex("Diffuse", 2D) = "white" {}
		_BumpMap("Normal", 2D) = "normal" {}

		_OcclusionMap("AO Texture", 2D) = "white"{}
		_OcclusionStrength ("AO Strength", float) = 1

		//_DetailNormalTex("DetailNormal", 2D) = "normal"{}
		//_DetailNormalTile("DetailNormalTile", Float) = 1.0
		//_DetailNormalWeight("DetailNormalWeight" ,Range(0,10)) = 1

		_MaterialTex("Smooth(G)", 2D) = "normal"{}

		_SkinSmoothness("_SkinSmoothness ", Range(0,1)) = 0.31
		_SkinF0 ("_SkinF0", Range(0.02, 0.08)) = 0.02

		_SSSWeight ("SSS Weight", Range(0, 1)) = 1
		_GlobalSSSWeight("Global SSS Weight", Range(0, 1)) = 1
		_LookupDiffuseSpec("SSS Lut", 2D) = "gray" {}
		_BumpinessDR("Diffuse Bumpiness R", Range(0,1)) = 0.1
		_BumpinessDG("Diffuse Bumpiness G", Range(0,1)) = 0.6
		_BumpinessDB("Diffuse Bumpiness B", Range(0,1)) = 0.7
		_SSSOffset ("SSS Offset", Range(-1, 1)) = 0

	}
	CGINCLUDE

	#define EPSILON 1.0e-4

	float3 RGB2HSV(float3 c)
	{
		float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
		float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
		float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
		float d = q.x - min(q.w, q.y);
		float e = 1.0e-4;
		return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
	}

	float3 HSV2RGB(float3 c)
	{
		float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
		float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
		return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
	}


	float _SSSWeight;
	float _GlobalSSSWeight;

	sampler2D _LookupDiffuseSpec;
	uniform float _BumpinessDR;
	uniform float _BumpinessDG;
	uniform float _BumpinessDB;
	float _SSSOffset;

	#include "UnityStandardCore.cginc"	
	float3 PreintegratedSSS(sampler2D _BumpMap,
		float2 uv, float4 tangent2World[3],
		float3 normalWorld, float3 eyeVec,
		float3 col,
		UnityLight light,
		float thick)
	{

		float3 texNormalLow = UnpackNormal(tex2Dbias(_BumpMap, half4(uv, 0, 3)));
		float3 wNormalLow = texNormalLow.x * tangent2World[0].xyz
			+ texNormalLow.y * tangent2World[1]
			+ texNormalLow.z * tangent2World[2];
		float3 NormalR = normalize(lerp(wNormalLow, normalWorld, _BumpinessDR));
		float3 NormalG = normalize(lerp(wNormalLow, normalWorld, _BumpinessDG));
		float3 NormalB = normalize(lerp(wNormalLow, normalWorld, _BumpinessDB));


		float3 lightDir = light.dir;
		float3 diffNdotL = 0.5 + 0.5 * half3(
			dot(NormalR, lightDir),
			dot(NormalG, lightDir),
			dot(NormalB, lightDir));
		float scattering = saturate((1 - thick + _SSSOffset));

		half3 preintegrate = half3(
			tex2D(_LookupDiffuseSpec, half2(diffNdotL.r, scattering)).r,
			tex2D(_LookupDiffuseSpec, half2(diffNdotL.g, scattering)).g,
			tex2D(_LookupDiffuseSpec, half2(diffNdotL.b, scattering)).b);
		preintegrate *= 2;

		thick = 1 - thick;
		float tt = -thick * thick;
		half NdotL = dot(normalWorld, lightDir);
		float halfLambert = NdotL * 0.5 + 0.5;
		half3 translucencyProfile =
			float3(0.233, 0.455, 0.649) * exp(tt / 0.0064) +
			float3(0.100, 0.336, 0.344) * exp(tt / 0.0484) +
			float3(0.118, 0.198, 0.000) * exp(tt / 0.1870) +
			float3(0.113, 0.007, 0.007) * exp(tt / 0.5670) +
			float3(0.358, 0.004, 0.000) * exp(tt / 1.9900) +
			float3(0.078, 0.000, 0.000) * exp(tt / 7.4100);
		half3 translucency = saturate((1 - NdotL)*halfLambert*(1 + thick)) * translucencyProfile;
		translucency *= 0.5;
		translucency = saturate(translucency);
		col *= lerp(1, preintegrate + translucency * _GlobalSSSWeight, _SSSWeight);
		return col;
	}

	ENDCG
	SubShader
	{
		Tags { "RenderType" = "Opaque" }
		LOD 100
		
		Pass
		{

			Name "FORWARD"
			Tags{ "LightMode" = "ForwardBase" "Queue" = "Geometry"}


			CGPROGRAM
			#pragma vertex vertForwardBase
			#pragma fragment fragForwardBaseSkin
			#pragma multi_compile_fwdbase
			// make fog work
			#pragma multi_compile_fog

			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			//#include "BD_FunctionLibrary.cginc"

			sampler2D _MaterialTex;
			float _SkinSmoothness;
			float _SkinF0;

			half4 fragForwardBaseSkin(VertexOutputForwardBase i) : SV_Target
			{
				UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);

				FRAGMENT_SETUP(s)
				UNITY_SETUP_INSTANCE_ID(i);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

				UnityLight light = MainLight();
				UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld);

				float4 misc = tex2D(_MaterialTex, i.tex.xy);
				s.smoothness = misc.g * _SkinSmoothness;
				s.specColor = _SkinF0;

				half occlusion = Occlusion(i.tex.xy);
				UnityGI gi = FragmentGI(s, occlusion, i.ambientOrLightmapUV, atten, light);

				s.diffColor = PreintegratedSSS(_BumpMap,
					i.tex.xy, i.tangentToWorldAndPackedData,
					s.normalWorld, s.eyeVec,
					s.diffColor,
					light,
					1 - misc.r);
				half4 c = UNITY_BRDF_PBS(s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect);

				UNITY_EXTRACT_FOG_FROM_EYE_VEC(i);
				UNITY_APPLY_FOG(_unity_fogCoord, c.rgb);
				return OutputForward(c, s.alpha);
			}

			ENDCG
		}
		Pass
		{

			Name "FORWARD_DELTA"
			Tags{ "LightMode" = "ForwardAdd" "Queue" = "Geometry"}
			Blend One One
			Fog { Color(0,0,0,0) } // in additive pass fog should be black
			ZWrite Off
			ZTest LEqual


			CGPROGRAM
			#pragma vertex vertForwardAdd
			#pragma fragment fragForwardAddSkin
			#pragma multi_compile_fwdadd
			// make fog work
			#pragma multi_compile_fog

			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			//#include "BD_FunctionLibrary.cginc"

			sampler2D _MaterialTex;
			float _SkinSmoothness;
			float _SkinF0;

			half4 fragForwardAddSkin(VertexOutputForwardAdd i) : SV_Target
			{
				UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);

				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

				FRAGMENT_SETUP_FWDADD(s)

				UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld)
				UnityLight light = AdditiveLight(IN_LIGHTDIR_FWDADD(i), atten);
				UnityIndirect noIndirect = ZeroIndirect();

				float4 misc = tex2D(_MaterialTex, i.tex.xy);
				s.smoothness = misc.g * _SkinSmoothness;
				s.specColor = _SkinF0;


				half4 c = UNITY_BRDF_PBS(s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, light, noIndirect);

				c.rgb = PreintegratedSSS(_BumpMap,
					i.tex.xy, i.tangentToWorldAndLightDir,
					s.normalWorld, s.eyeVec, 
					c.rgb,
					light,
					1 - misc.r);
				UNITY_EXTRACT_FOG_FROM_EYE_VEC(i);
				UNITY_APPLY_FOG_COLOR(_unity_fogCoord, c.rgb, half4(0, 0, 0, 0)); // fog towards black in additive pass
				return OutputForward(c, s.alpha);
				//UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);

				//FRAGMENT_SETUP_FWDADD(s)
				//UNITY_SETUP_INSTANCE_ID(i);
				//UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

				//UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld);
				//UnityLight light = AdditiveLight(IN_LIGHTDIR_FWDADD(i), 1);

				//float4 misc = tex2D(_MaterialTex, i.tex.xy);
				//s.smoothness = misc.g * _SkinSmoothness;
				//s.specColor = _SkinF0;

				//half occlusion = Occlusion(i.tex.xy);
				//UnityGI gi = FragmentGI(s, occlusion, 0, atten, light);

				//half4 c = UNITY_BRDF_PBS(s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect);
				//c.rgb += Emission(i.tex.xy);
				//c.rgb = PreintegratedSSS(_BumpMap,
				//	i.tex.xy, i.tangentToWorldAndLightDir,
				//	s.normalWorld, s.eyeVec,
				//	c.rgb,
				//	light,
				//	1 - misc.r);

				//UNITY_EXTRACT_FOG_FROM_EYE_VEC(i);
				//UNITY_APPLY_FOG(_unity_fogCoord, c.rgb);
				//return OutputForward(c, s.alpha);
			}

			ENDCG
		}

	}
		Fallback "VertexLit"
}
