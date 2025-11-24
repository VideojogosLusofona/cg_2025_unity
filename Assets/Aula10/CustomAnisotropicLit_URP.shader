Shader "Custom/AnisotropicLit_URP"
{
    Properties
    {
        _Color      ("Base Color", Color) = (1, 1, 1, 1)
        _SpecColor  ("Specular Color", Color) = (1, 1, 1, 1)

        // Anisotropy "radius" in tangent/bitangent directions
        _AnisoX     ("Anisotropy X (Tangent)", Range(0.05, 2.0)) = 0.3
        _AnisoY     ("Anisotropy Y (Bitangent)", Range(0.05, 2.0)) = 1.0

        _SpecPower  ("Specular Power", Range(1.0, 128.0)) = 32.0
    }

    SubShader
    {
        Tags
        {
            "RenderType"   = "Opaque"
            "Queue"        = "Geometry"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM

            #pragma vertex   vert
            #pragma fragment frag

            // Basic URP includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // GPU-instancing support (optional but nice to have)
            #pragma multi_compile_instancing

            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float4 _SpecColor;
                float  _AnisoX;
                float  _AnisoY;
                float  _SpecPower;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
                float2 uv         : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 normalWS   : TEXCOORD0;
                float3 tangentWS  : TEXCOORD1;
                float3 bitangentWS: TEXCOORD2;
                float3 viewDirWS  : TEXCOORD3;
                float3 posWS      : TEXCOORD4;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert (Attributes IN)
            {
                Varyings OUT;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                // Position & normals from URP helper functions
                VertexPositionInputs posInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   nrmInputs = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);

                OUT.positionCS   = posInputs.positionCS;
                OUT.posWS        = posInputs.positionWS;
                OUT.normalWS     = nrmInputs.normalWS;
                OUT.tangentWS    = nrmInputs.tangentWS;
                OUT.bitangentWS  = nrmInputs.bitangentWS;

                OUT.viewDirWS    = GetWorldSpaceViewDir(posInputs.positionWS);

                return OUT;
            }

            // Simple main-light-only anisotropic BRDF
            half4 frag (Varyings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                float3 N = normalize(IN.normalWS);
                float3 T = normalize(IN.tangentWS);
                float3 B = normalize(IN.bitangentWS);

                float3 V = normalize(IN.viewDirWS);

                // Get main light (directional)
                Light light = GetMainLight();
                float3 L = normalize(light.direction); // from surface to light

                float NdotL = saturate(dot(N, L));
                if (NdotL <= 0.0)
                {
                    // No light on the back side: just return ambient/base if you want
                    return float4(_Color.rgb * 0.0, _Color.a);
                }

                // Half vector
                float3 H = normalize(L + V);

                // Transform H into tangent space
                float3x3 TBN = float3x3(T, B, N);
                float3 hLocal = mul(TBN, H);   // x=tangent, y=bitangent, z=normal

                // Elliptical anisotropic specular lobe (very simple model)
                float ellipse =
                    (hLocal.x * hLocal.x) / (_AnisoX * _AnisoX) +
                    (hLocal.y * hLocal.y) / (_AnisoY * _AnisoY);

                float spec = pow(saturate(1.0 - ellipse), _SpecPower);

                // Diffuse + specular
                float3 baseColor = _Color.rgb;
                float3 specColor = _SpecColor.rgb;

                float lightAtten = light.distanceAttenuation * light.shadowAttenuation;

                float3 diffuse  = baseColor * light.color * NdotL * lightAtten;
                float3 specular = specColor * light.color * spec * lightAtten;

                float3 finalCol = diffuse + specular;

                return float4(finalCol, _Color.a);
            }

            ENDHLSL
        }
    }
}
