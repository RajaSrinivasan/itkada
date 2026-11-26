with Interfaces;
with Itklib.Pixel_Signature;

package Itklib.Pixels.UInt16 is new Itklib.Pixel_Signature
  (Pixel => Interfaces.Unsigned_16, Kind => Itklib.UInt16);
