with Interfaces;
with Itklib.Pixel_Signature;

package Bad_Pixel is new Itklib.Pixel_Signature
  (Pixel => Interfaces.Unsigned_32, Kind => Itklib.UInt16);
