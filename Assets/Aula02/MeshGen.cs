using UnityEngine;

[RequireComponent(typeof(MeshFilter))]
[RequireComponent(typeof(MeshRenderer))]
public class MeshGen : MonoBehaviour
{
    [SerializeField] private Material   material;
    [SerializeField] private Vector2    size = new Vector2(1f, 1f);
    [SerializeField] private int        sideVertexCount = 4;

    void Start()
    {
        GenerateMesh();        
    }

    void GenerateMesh()
    {
        Mesh mesh = new Mesh();
        mesh.name = "GeneratedPlane";

        int vertsPerRow = sideVertexCount;
        int vertsPerCol = sideVertexCount;

        // Vertices & UVs
        Vector3[] vertices = new Vector3[vertsPerRow * vertsPerCol];
        Vector3[] normals = new Vector3[vertsPerRow * vertsPerCol];
        Vector2[] uvs = new Vector2[vertsPerRow * vertsPerCol];
        Color[] colors = new Color[vertsPerRow * vertsPerCol];

        for (int y = 0; y < vertsPerCol; y++)
        {
            for (int x = 0; x < vertsPerRow; x++)
            {
                int i = y * vertsPerRow + x;

                float uf = (float)x / (vertsPerRow - 1);
                float vf = (float)y / (vertsPerCol - 1);

                float xf = size.x * (uf - 0.5f);
                float yf = size.y * (vf - 0.5f);

                vertices[i] = new Vector3(xf, 0f, yf);
                normals[i] = Vector3.up;
                uvs[i] = new Vector2(uf, vf);
                colors[i] = new Color(uf, 0, 0, 1.0f);
            }
        }

        // Triangles
        int quadsPerRow = vertsPerRow - 1;
        int quadsPerCol = vertsPerCol - 1;
        int[] triangles = new int[quadsPerRow * quadsPerCol * 6];

        int t = 0;
        for (int y = 0; y < quadsPerCol; y++)
        {
            for (int x = 0; x < quadsPerRow; x++)
            {
                int i = y * vertsPerRow + x;

                int i0 = i;
                int i1 = i + 1;
                int i2 = i + vertsPerRow;
                int i3 = i + vertsPerRow + 1;

                // Triangle 1
                triangles[t++] = i0;
                triangles[t++] = i2;
                triangles[t++] = i1;

                // Triangle 2
                triangles[t++] = i1;
                triangles[t++] = i2;
                triangles[t++] = i3;
            }
        }

        mesh.vertices = vertices;
        mesh.normals = normals;
        mesh.colors = colors;
        mesh.uv = uvs;
        mesh.triangles = triangles;
        mesh.RecalculateNormals();
        mesh.RecalculateTangents();
        mesh.RecalculateBounds();

        // Apply to components
        MeshFilter filter = GetComponent<MeshFilter>();
        filter.mesh = mesh;

        MeshRenderer renderer = GetComponent<MeshRenderer>();
        if (material != null)
            renderer.sharedMaterial = material;
    }
}
