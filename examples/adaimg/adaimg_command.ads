with Ada.Strings.Bounded;

package Adaimg_Command with SPARK_Mode => On is
   --  Hand-written adaimg argument parser. ImageMagick-like names:
   --  identify, -blur sigma, -median r, -threshold lo:hi, -rescale lo:hi,
   --  -resize N%, -flip x|y, -crop WxH+X+Y, -edge. Two positional files
   --  with no options is a PNG copy.

   Max_Path : constant := 4_096;
   Max_Ops : constant := 32;
   Max_Args : constant := 64;

   package Texts is new Ada.Strings.Bounded.Generic_Bounded_Length (Max_Path);

   type Arg_Array is array (Positive range <>) of Texts.Bounded_String;

   type Mode_Kind is (Help, Identify, Pipeline, Usage_Error);
   type Op_Kind is
     (Blur, Median, Threshold, Rescale, Resize_Shrink, Resize_Resample,
      Resize_Copy, Flip, Crop, Edge);

   type Operation is record
      Kind : Op_Kind := Edge;
      Sigma : Long_Float := 1.0;
      Radius : Natural := 1;
      Low : Long_Float := 0.0;
      High : Long_Float := 0.0;
      Shrink_Factor : Positive := 2;
      Scale : Long_Float := 1.0;
      Flip_Axis : Positive := 1;
      Crop_W : Positive := 1;
      Crop_H : Positive := 1;
      Crop_X : Natural := 0;
      Crop_Y : Natural := 0;
   end record;

   type Op_Array is array (1 .. Max_Ops) of Operation;

   type Command is record
      Mode : Mode_Kind := Usage_Error;
      Input : Texts.Bounded_String;
      Output : Texts.Bounded_String;
      Count : Natural := 0;
      Ops : Op_Array := [others => <>];
      Message : Texts.Bounded_String;
   end record;

   function Parse (Args : Arg_Array) return Command with
     Pre => Args'Length <= Max_Args,
     Global => null;

   function Usage return String;

end Adaimg_Command;
