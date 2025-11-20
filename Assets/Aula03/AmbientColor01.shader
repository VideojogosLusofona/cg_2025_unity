Shader "Custom Lighting/Ambient Color (Explicit Color)"
{
    Properties
    {
        _AmbientColor("Ambient Color", Color) = (0.2, 0.2, 0.2, 1.0)
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

            // SRP Batcher-compatible material constants
            CBUFFER_START(UnityPerMaterial)
                float4 _AmbientColor;
            CBUFFER_END

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
                return _AmbientColor;
            }
            ENDHLSL
        }
    }

    Fallback Off
}
