Shader "Custom Lighting/Diffuse With NormalMap"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _NormalMap ("Normal Map (RGB tangent-space)", 2D) = "bump" {}
        _NormalStrength ("Normal Strength", Range(0,2)) = 1
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" }

        Pass
        {
            Name "ForwardURP"
            Tags { "LightMode"="UniversalForward" }

            Cull Back
            ZWrite On
            ZTest LEqual
            Blend One Zero

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex   vert
            #pragma fragment frag

            // IMPORTANT: apply to both stages (not just fragment)
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _FORWARD_PLUS

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float3 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;   // xyz = tangent, w = handedness sign - normal Unity packing with RecalculateTangents()
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float2 uv         : TEXCOORD1;

                // We pass the explicit TBN basis to the fragment (for clarity) - we could pass the normal/tangent only, and recompute the binormal in the pixel shader
                float3 T_ws       : TEXCOORD2;
                float3 B_ws       : TEXCOORD3;
                float3 N_ws       : TEXCOORD4;

                // Needed for clustered Forward+
                float2 screenUV   : TEXCOORD5;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float _NormalStrength;
            CBUFFER_END

            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

            // Simple Lambert (no shadows)
            static inline half3 Lambert(half3 N, Light L)
            {
                half nl = saturate(dot(N, L.direction));
                return L.color * nl * L.distanceAttenuation;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                float3 posWS = TransformObjectToWorld(IN.positionOS);
                float3 N_ws  = normalize(TransformObjectToWorldNormal(IN.normalOS));

                // ----- Explicit TBN construction -----
                // Transform object-space tangent to world-space
                float3 T_ws = normalize(TransformObjectToWorldDir(IN.tangentOS.xyz));
                // Reconstruct B from N x T and the handedness (tangent.w)
                float3 B_ws = normalize(cross(N_ws, T_ws)) * IN.tangentOS.w;

                // NOTE: You could replace the block above with Unity's helpers, e.g.:
                // VertexNormalInputs n = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                // float3 T_ws = n.tangentWS; float3 B_ws = n.bitangentWS; float3 N_ws = n.normalWS;
                // (Kept explicit here to make the tangent-space construction obvious.)

                OUT.positionWS = posWS;
                OUT.positionCS = TransformWorldToHClip(posWS);
                OUT.uv         = IN.uv;

                OUT.T_ws = T_ws;
                OUT.B_ws = B_ws;
                OUT.N_ws = N_ws;

                OUT.screenUV = GetNormalizedScreenSpaceUV(OUT.positionCS);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // ----- Sample tangent-space normal and unpack explicitly -----
                // Expecting a standard RGB tangent-space normal map:
                // tex = (nx, ny, nz) in [0..1] -> remap to [-1..1]
                // This only happens if the normal map is loaded as a normal texture, and not as a normal map
                // If it is a normal map (and uses compression, etc), we have to use Unity's DecodeNormalMap() function instead to replace the following lines with just this:
                // float4 nmTex = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, IN.uv);
                // float3 n_tan = UnpackNormalScale(nmTex, _NormalStrength); // applies strength + renorm
                float3 n_tan = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, IN.uv).xyz * 2.0 - 1.0;
                n_tan.xy *= _NormalStrength;
                n_tan = normalize(n_tan);

                // ----- Transform tangent-space normal to world-space using our explicit TBN -----
                // TBN with columns = T, B, N
                float3x3 TBN = float3x3(IN.T_ws, IN.B_ws, IN.N_ws);
                float3 N_ws  = normalize(mul(TBN, n_tan));

                // Base color
                half3 albedo = _BaseColor.rgb;

                // ----- Additional (non-directional) lights only -----
                half3 diffuse = 0;

                #if defined(_ADDITIONAL_LIGHTS)
                    // Forward+: need a minimal InputData for clustered light fetching
                    InputData inputData = (InputData)0;
                    inputData.positionWS              = IN.positionWS;
                    inputData.normalWS                = N_ws;
                    inputData.viewDirectionWS         = GetWorldSpaceNormalizeViewDir(IN.positionWS);
                    inputData.normalizedScreenSpaceUV = IN.screenUV;

                    uint addCount = GetAdditionalLightsCount();
                    LIGHT_LOOP_BEGIN(addCount)
                        Light L = GetAdditionalLight(lightIndex, IN.positionWS, half4(1,1,1,1));
                        diffuse += Lambert(N_ws, L);
                    LIGHT_LOOP_END
                #endif

                // Final
                half3 color = diffuse * albedo;
                return half4(color, 1);
            }
            ENDHLSL
        }
    }

    Fallback Off
}
