using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PreintegrateSSS : MonoBehaviour
{
    public ComputeShader PreintegrateSSSCompute;
    // Start is called before the first frame update
    void Start()
    {
        RenderTexture lut = new RenderTexture(256, 256, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear)
        {
            enableRandomWrite = true,
            dimension = UnityEngine.Rendering.TextureDimension.Tex2D,
            wrapMode = TextureWrapMode.Clamp,
            filterMode = FilterMode.Bilinear,
        };
        lut.Create();
        int KernelPreintegrateSSS = PreintegrateSSSCompute.FindKernel("KernelPreintegrateSSS");
        PreintegrateSSSCompute.SetTexture(KernelPreintegrateSSS, "Lut", lut);
        PreintegrateSSSCompute.SetVector("Size", new Vector4(lut.width, lut.height, 0,0));
        PreintegrateSSSCompute.Dispatch(KernelPreintegrateSSS, lut.width / 8, lut.height / 8, 1);
        RenderTexture tmp = RenderTexture.active;
        RenderTexture.active = lut;
        RenderTexture.active = tmp;
        Texture2D pic = new Texture2D(lut.width, lut.height, TextureFormat.RGBA32, true, true);
        pic.ReadPixels(new Rect(0, 0, lut.width, lut.height), 0, 0);
        byte[] bytes = pic.EncodeToPNG();
        pic.Apply(true, true);
        System.IO.File.WriteAllBytes("Lut.png", bytes);
        Destroy(pic);
        Destroy(lut);
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
