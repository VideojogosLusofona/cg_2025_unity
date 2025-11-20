Shader "Custom Lighting/Diffuse Lighting (Per-Vertex)"
{
    Properties { }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" }

        Pass
        {
            Name "ForwardVertexLit"
            Tags { "LightMode"="UniversalForward" }

            Cull Back
            ZWrite On
            ZTest LEqual
            Blend One Zero

            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #pragma target   4.5

            // IMPORTANT: apply to both stages (not only fragment)
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _FORWARD_PLUS

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes {
                float3 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings {
                float4 positionCS : SV_POSITION;
                half4  color      : COLOR0;
            };

            static half3 Lambert(half3 N, Light L)
            {
                // L.direction is normalized; includes direction for punctual lights too
                half nl = saturate(dot(N, L.direction));
                return L.color * nl * L.distanceAttenuation;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                float3 positionWS = TransformObjectToWorld(IN.positionOS);
                OUT.positionCS    = TransformWorldToHClip(positionWS);

                half3 N = normalize(TransformObjectToWorldNormal(IN.normalOS));

                // Simple ambient (you can swap for SH if desired)
                half3 ambient = unity_AmbientSky.rgb;

                // Directional main light (0 if none exists)
                Light mainLight = GetMainLight();
                half3 diffuse   = Lambert(N, mainLight);

                // Additional (point/spot) lights
                #if defined(_ADDITIONAL_LIGHTS)
                    InputData inputData = (InputData)0;
                    inputData.positionWS                = positionWS;
                    inputData.normalWS                  = N;
                    inputData.viewDirectionWS           = GetWorldSpaceNormalizeViewDir(positionWS);
                    inputData.normalizedScreenSpaceUV   = GetNormalizedScreenSpaceUV(OUT.positionCS);

                    uint addCount = GetAdditionalLightsCount();
                    LIGHT_LOOP_BEGIN(addCount)
                        Light L = GetAdditionalLight(lightIndex, inputData.positionWS, half4(1,1,1,1));
                        diffuse += Lambert(N, L);
                    LIGHT_LOOP_END
                #endif

                OUT.color = half4(ambient + diffuse, 1);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                return IN.color;
            }
            ENDHLSL
        }
    }

    Fallback Off
}
