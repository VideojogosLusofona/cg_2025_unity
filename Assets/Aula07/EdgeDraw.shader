Shader "Other/Edge Draw (Triangles -> Edge Quads)"
{
    Properties
    {
        _EdgeColor ("Edge Color", Color) = (0,0,0,1)
        _EdgeWidth ("Edge Width (World Units)", Float) = 0.01
    }
    SubShader
    {
        Tags{ "RenderPipeline"="UniversalRenderPipeline" "Queue"="Transparent" }

        Pass
        {
            Name "UniversalForward"
            Tags{ "LightMode"="UniversalForward" }

            Cull Off
            ZTest LEqual
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma target 4.0
            #pragma vertex   vert
            #pragma geometry geom
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct VertexInput
            {
                float4 vertex : POSITION;
            };

            struct VertexOutput
            {
                float3 wpos : TEXCOORD0;
            };

            struct PixelInput
            {
                float4 clip : SV_POSITION;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _EdgeColor;
                float  _EdgeWidth;
            CBUFFER_END

            VertexOutput vert(VertexInput v)
            {
                VertexOutput o;
                o.wpos = TransformObjectToWorld(v.vertex.xyz);
                return o;
            }

            // Emit a camera-facing quad along edge p0->p1 with world-space thickness.
            void EmitEdgeQuad(float3 p0, float3 p1, float3 camPos, float width,
                              inout TriangleStream<PixelInput> triStream)
            {
                float3 edge = p1 - p0;
                float  len  = length(edge);
                if (len < 1e-6) return;

                float3 eDir = edge / len;
                float3 mid  = 0.5 * (p0 + p1);
                float3 vDir = normalize(camPos - mid);

                // perpendicular to edge, facing camera
                float3 up = cross(vDir, eDir);
                float upLen = length(up);
                if (upLen < 1e-6) return;
                up /= upLen;

                float3 off = up * (width * 0.5);

                float3 a = p0 - off;
                float3 b = p0 + off;
                float3 c = p1 + off;
                float3 d = p1 - off;

                PixelInput o;
                // tri 1: a,b,c
                o.clip = TransformWorldToHClip(a); triStream.Append(o);
                o.clip = TransformWorldToHClip(b); triStream.Append(o);
                o.clip = TransformWorldToHClip(c); triStream.Append(o);
                triStream.RestartStrip();

                // tri 2: a,c,d
                o.clip = TransformWorldToHClip(a); triStream.Append(o);
                o.clip = TransformWorldToHClip(c); triStream.Append(o);
                o.clip = TransformWorldToHClip(d); triStream.Append(o);
                triStream.RestartStrip();
            }

            // We take TRIANGLES as input and emit ONLY edge quads (no original surface).
            [maxvertexcount(24)] // 3 edges × 2 tris per quad × 3 verts
            void geom(triangle VertexOutput IN[3], inout TriangleStream<PixelInput> triStream)
            {
                float3 p0 = IN[0].wpos;
                float3 p1 = IN[1].wpos;
                float3 p2 = IN[2].wpos;

                float3 camPos = GetCameraPositionWS();

                EmitEdgeQuad(p0, p1, camPos, _EdgeWidth, triStream);
                EmitEdgeQuad(p1, p2, camPos, _EdgeWidth, triStream);
                EmitEdgeQuad(p2, p0, camPos, _EdgeWidth, triStream);
            }

            float4 frag(PixelInput i) : SV_Target
            {
                return _EdgeColor;
            }
            ENDHLSL
        }
    }

    FallBack Off
}
