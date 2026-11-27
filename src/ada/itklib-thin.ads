with Interfaces;
with Interfaces.C;
with System;

package Itklib.Thin with SPARK_Mode => Off is
   --  Private C binding. Application code should use Itklib.Images and
   --  the filter packages. Handles are System.Address values owned by
   --  controlled types; null is an empty handle.

   type Extent_Array is array (Positive range <>) of Interfaces.Unsigned_64;
   type Index_Array is array (Positive range <>) of Interfaces.Integer_64;
   type Double_Array is array (Positive range <>) of Interfaces.C.double;

   function ITK_Version return String;
   function Is_Supported
     (Kind : Itklib.Pixel_Kind; Dimension : Positive) return Boolean;
   function Debug_Live_Objects return Natural;
   function Debug_Live_Wrappers return Natural;

   procedure Register (Handle : System.Address);
   procedure Unregister (Handle : System.Address);
   function Reference_Count (Handle : System.Address) return Natural;

   function Image_New
     (Kind : Itklib.Pixel_Kind; Extent : Extent_Array) return System.Address;

   procedure Image_Buffer
     (Handle : System.Address; Data : out System.Address;
      Count : out Interfaces.Unsigned_64);

   procedure Image_Get_Geometry
     (Handle : System.Address; Index : out Index_Array; Size : out Extent_Array;
      Spacing : out Double_Array; Origin : out Double_Array;
      Direction : out Double_Array);

   procedure Image_Set_Spacing (Handle : System.Address; Spacing : Double_Array);
   procedure Image_Set_Origin (Handle : System.Address; Origin : Double_Array);
   procedure Image_Set_Direction
     (Handle : System.Address; Direction : Double_Array);

   function Reader_New
     (Kind : Itklib.Pixel_Kind; Dimension : Positive) return System.Address;
   procedure Reader_Set_File (Handle : System.Address; Path : String);

   function Writer_New
     (Kind : Itklib.Pixel_Kind; Dimension : Positive) return System.Address;
   procedure Writer_Set_File (Handle : System.Address; Path : String);

   function Gaussian_New
     (Kind : Itklib.Pixel_Kind; Dimension : Positive) return System.Address;
   procedure Gaussian_Set_Variance
     (Handle : System.Address; Variance : Double_Array);
   procedure Gaussian_Set_Use_Image_Spacing
     (Handle : System.Address; Enabled : Boolean);

   procedure Set_Input
     (Filter : System.Address; Image : System.Address; Index : Natural := 0);
   procedure Update (Process : System.Address);
   function Get_Output
     (Process : System.Address; Index : Natural := 0) return System.Address;
end Itklib.Thin;
