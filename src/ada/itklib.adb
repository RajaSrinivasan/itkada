with Itklib.Thin;

package body Itklib with SPARK_Mode => Off is

   function ITK_Version return String is
   begin
      return Thin.ITK_Version;
   end ITK_Version;

   function Debug_Live_Objects return Natural is
   begin
      return Thin.Debug_Live_Objects;
   end Debug_Live_Objects;

   function Debug_Live_Wrappers return Natural is
   begin
      return Thin.Debug_Live_Wrappers;
   end Debug_Live_Wrappers;

end Itklib;
