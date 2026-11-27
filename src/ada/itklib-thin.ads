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
   procedure Image_Buffer_Lock (Handle : System.Address);
   procedure Image_Buffer_Unlock (Handle : System.Address);
   procedure Image_Disconnect (Handle : System.Address);
   procedure Image_Index_To_Physical
     (Handle : System.Address; Index : Index_Array; Point : out Double_Array);
   procedure Image_Physical_To_Index
     (Handle : System.Address; Point : Double_Array; Index : out Index_Array);

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
   procedure Gaussian_Set_Maximum_Error
     (Handle : System.Address; Maximum_Error : Double_Array);

   type Filter_Kind is
     (Median, Threshold, Rescale, Shrink, Resample, Flip, Extract, Gradient,
      Statistics);

   function Filter_New
     (Kind : Filter_Kind; Pixel : Itklib.Pixel_Kind; Dimension : Positive)
      return System.Address;
   procedure Median_Set_Radius (Handle : System.Address; Radius : Extent_Array);
   procedure Threshold_Set
     (Handle : System.Address; Lower, Upper, Inside_Value, Outside_Value : Long_Float);
   procedure Rescale_Set_Output_Range
     (Handle : System.Address; Minimum, Maximum : Long_Float);
   procedure Shrink_Set_Factors (Handle : System.Address; Factors : Extent_Array);
   procedure Resample_Configure
     (Handle : System.Address; Extent : Extent_Array; Spacing, Origin : Double_Array;
      Direction : Double_Array; Default_Pixel : Long_Float);
   procedure Resample_Set_Uniform_Scale (Handle : System.Address; Scale : Long_Float);
   procedure Flip_Set_Axes
     (Handle : System.Address; Axes : Extent_Array; About_Origin : Boolean);
   procedure Extract_Set_Region
     (Handle : System.Address; Start : Index_Array; Extent : Extent_Array);
   procedure Gradient_Set_Use_Image_Spacing
     (Handle : System.Address; Enabled : Boolean);
   procedure Statistics_Get
     (Handle : System.Address; Minimum, Maximum, Mean : out Long_Float);

   procedure Set_Input
     (Filter : System.Address; Image : System.Address; Index : Natural := 0);
   procedure Update (Process : System.Address);
   procedure Modified (Process : System.Address);
   procedure Update_Largest_Possible_Region (Process : System.Address);
   procedure Set_Number_Of_Work_Units (Process : System.Address; Count : Positive);
   function Get_Output
     (Process : System.Address; Index : Natural := 0) return System.Address;
end Itklib.Thin;
