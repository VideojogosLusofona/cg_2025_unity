Shader "Custom Lighting/Diffuse Lighting (Crosshatched Shadows)"
{
    Properties
    {
        _HatchTex("Crosshatch Texture", 2D) = "white" {}
        _Scale("World UV Scale", Float) = 4.0
        _Rotation("World UV Rotation", Range(0, 6.28)) = 0
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Opaque"
            "Queue"="Geometry"
        }

        Pass
        {
            Name "ForwardUnlit"
            Tags { "LightMode"="UniversalForward" }

            Cull Back
            ZWrite On
            ZTest LEqual
            Blend One Zero  // Opaque

            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #pragma target   4.5

            // URP lighting keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile  _ _ADDITIONAL_LIGHTS
            #pragma multi_compile  _ _FORWARD_PLUS
            #pragma multi_compile  _ _ADDITIONAL_LIGHT_SHADOWS    
            #pragma multi_compile  _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4  _BaseColor;
                float   _Scale;
                float   _Rotation;
            CBUFFER_END
            TEXTURE2D(_HatchTex); SAMPLER(sampler_HatchTex);

            struct Attributes
            {
                float3 positionOS : POSITION;  // object-space vertex position                
                float3 normalOS   : NORMAL;    // object-space vertex normal
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
            };

            static half2 GetProjectedUV(half3 worldPos, half3 normal)
            {
                float3 up = abs(normal.y) < 0.999 ? float3(0,1,0) : float3(1,0,0);
                float3 tangent  = normalize(cross(up, normal));
                float3 binormal  = cross(normal, tangent);

                // --- project world position onto that local plane ---
                float u = dot(worldPos, tangent);
                float v = dot(worldPos, binormal);
                float c = cos(_Rotation);
                float s = sin(_Rotation);
                float2 uv = float2(c * u - s * v, c * v + s * u);

                return uv;
            }

            static half3 Lambert(half3 N, Light L, half3 worldPos)
            {
                half nl = saturate(dot(N, L.direction));
                half lighting = L.shadowAttenuation * 1.2f;

                // Build world coordinates
                float2 uv = GetProjectedUV(worldPos * _Scale, N);

                float hatchSample = SAMPLE_TEXTURE2D(_HatchTex, sampler_HatchTex, uv).r;
                float hatchMask = step(1 - lighting, hatchSample);
                
                return hatchMask * nl * L.color;
            }

            Varyings vert (Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS);
                OUT.positionCS    = TransformWorldToHClip(positionWS);
                OUT.positionWS    = positionWS;
                OUT.normalWS      = TransformObjectToWorldNormal(IN.normalOS);
                return OUT;
            }

            half4 frag (Varyings IN) : SV_Target
            {
                // Normalize just in case (post-interp)
                half3 N = normalize(IN.normalWS);

                // Ambient (flat env color only)
                half3 ambient = unity_AmbientSky.rgb;

                // Main directional light
                Light mainLight = GetMainLight(TransformWorldToShadowCoord(IN.positionWS));
                half3 diffuse   = Lambert(N, mainLight, IN.positionWS);

                // --- Additional lights
                #if defined(_ADDITIONAL_LIGHTS)
                    // Forward+ requires an InputData in scope and the clustered loop macros:
                    InputData inputData = (InputData)0;
                    inputData.positionWS = IN.positionWS;
                    inputData.normalWS   = N;
                    inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(IN.positionWS);
                    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.positionCS);

                    // Forward+: non-main directionals (small fixed loop) - this is due to light clustering, I'll explain it in another class
                    #if USE_CLUSTER_LIGHT_LOOP
                    UNITY_LOOP // This does the same as [loop] in most cases, but is more "platform-agnostic"
                    for (uint li = 0; li < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); li++)
                    {
                        Light L = GetAdditionalLight(li, inputData.positionWS, half4(1,1,1,1)); // last parameter is shadowmask, we're not using shadows atm
                        diffuse += Lambert(N, L, IN.positionWS);
                    }
                    #endif

                    // Forward & Forward+ unified additional light loop - these are lights that aren't clustered
                    uint pixelLightCount = GetAdditionalLightsCount();
                    // The following is a special type of loop - for practical reasons, it's a loop, but in reality it might be or not
                    LIGHT_LOOP_BEGIN(pixelLightCount)
                        Light L = GetAdditionalLight(lightIndex, inputData.positionWS, half4(1,1,1,1));
                        diffuse += Lambert(N, L, IN.positionWS);
                    LIGHT_LOOP_END
                #endif

                return half4(ambient + diffuse, 1);
            }
            ENDHLSL
        }

        // Reuse the pass for shadowcasting from URP/Lit 
        UsePass "Universal Render Pipeline/Lit/ShadowCaster" 

        // If I want my own shadowcaster pass, comment the line above, and uncomment the code below
        /*Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }

            Cull Back
            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag

            // URP includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            struct Attributes
            {
                float3 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            Varyings vert (Attributes v)
            {
                Varyings o;

                float3 posWS   = TransformObjectToWorld(v.positionOS);

                o.positionCS = posWS;

                return o;
            }

            half4 frag (Varyings i) : SV_Target
            {
                // For opaque casters there’s nothing to do—just return.
                // If cutout is enabled, sample and clip by _Cutoff.
                return 0;
            }
            ENDHLSL
        }//*/
    }

    Fallback Off
}
