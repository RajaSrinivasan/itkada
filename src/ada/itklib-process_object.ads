with Ada.Finalization;
with System;

package Itklib.Process_Object with SPARK_Mode => Off is
   --  Limited controlled owner of one ITK process object (reader, writer,
   --  or filter). Adjust is not available: copy the output image instead.
   --  Do not share one pipeline across Ada tasks.

   type Object is abstract tagged limited private;

   procedure Update (Self : in out Object);
   procedure Modified (Self : in out Object);
   procedure Update_Largest_Possible_Region (Self : in out Object);
   procedure Set_Number_Of_Work_Units (Self : in out Object; Count : Positive);
   function Reference_Count (Self : Object) return Natural;

   --  Binding support used by the generic filter packages.
   function Raw_Handle (Self : Object) return System.Address;
   procedure Set_Raw_Handle (Self : in out Object; Handle : System.Address);

private
   type Object is abstract limited new Ada.Finalization.Limited_Controlled with
   record
      Handle : System.Address := System.Null_Address;
   end record;

   overriding procedure Finalize (Self : in out Object);
end Itklib.Process_Object;
