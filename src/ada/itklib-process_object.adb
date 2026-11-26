with Itklib.Thin;

package body Itklib.Process_Object with SPARK_Mode => Off is
   use type System.Address;

   overriding procedure Finalize (Self : in out Object) is
      Handle : constant System.Address := Self.Handle;
   begin
      Self.Handle := System.Null_Address;
      Thin.Unregister (Handle);
   end Finalize;

   procedure Update (Self : in out Object) is
   begin
      Thin.Update (Self.Handle);
   end Update;

   function Reference_Count (Self : Object) return Natural is
   begin
      return Thin.Reference_Count (Self.Handle);
   end Reference_Count;

   function Raw_Handle (Self : Object) return System.Address is
   begin
      return Self.Handle;
   end Raw_Handle;

   procedure Set_Raw_Handle (Self : in out Object; Handle : System.Address) is
   begin
      if Self.Handle /= System.Null_Address then
         Thin.Unregister (Self.Handle);
      end if;
      Self.Handle := Handle;
   end Set_Raw_Handle;

end Itklib.Process_Object;
