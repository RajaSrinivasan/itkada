with Interfaces;
with Itklib.Filters.Smoothing.Discrete_Gaussian;
with Itklib.Images;
with Itklib.Pixel_Signature;

procedure Unsupported_Main is
   package Sig is new Itklib.Pixel_Signature
     (Interfaces.IEEE_Float_32, Itklib.Float32);
   package Img is new Itklib.Images (Sig, 2);
   package Smooth is new Itklib.Filters.Smoothing.Discrete_Gaussian (Img, Img);
begin
   null;
end Unsupported_Main;
