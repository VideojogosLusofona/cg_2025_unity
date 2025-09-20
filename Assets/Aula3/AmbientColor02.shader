Shader "Custom Lighting/Ambient Color (From Options)"
{
    Properties
    {
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

            // URP core transforms & types
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float3 positionOS : POSITION;  // object-space vertex position
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION; // clip-space position
            };

            Varyings vert (Attributes IN)
            {
                Varyings OUT;
                // Object -> World -> Clip
                float3 positionWS = TransformObjectToWorld(IN.positionOS);
                OUT.positionCS = TransformWorldToHClip(positionWS);
                return OUT;
            }

            half4 frag (Varyings IN) : SV_Target
            {
                // Just output the parameter color; no lighting.
                return unity_AmbientSky;
            }
            ENDHLSL
        }
    }

    Fallback Off
}
