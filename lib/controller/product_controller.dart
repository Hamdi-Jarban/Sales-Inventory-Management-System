import 'package:untitled2/database.dart';
import 'package:untitled2/model/product.dart';

class ProductController{
  final table="products";
  Future<int>Insert(Map<String,dynamic> p)async{
    return DatabaseService.instance.insert(table, p);

  }
  Future<List<ProductModel>>GetAll()async{
    List<Map<String,dynamic>> productData=[];
    productData= await DatabaseService.instance.getAll(table);
    List<ProductModel> data=productData.map((e)=> ProductModel.fromMap(e)).toList();
     return data;
  }
  Future<bool>Delete(int id)async{
     int C=await DatabaseService.instance.Delete(table,id);
     if(C>0){return true;}
    return false;
  }
  Future<bool>Update(int id,ProductModel pr)async{
    Map<String,dynamic>product= pr.toMap();
    int C=await DatabaseService.instance.UpdataData(table,id,product);
    if(C>0){return true;}
    return false;
  }

  Future<ProductModel?>getByBarcode(String barcode)async{
    List<Map<String,dynamic>>product= await DatabaseService.instance.getByBarcode(table, barcode);
    List<ProductModel> ProductData= product.map((e)=>ProductModel.fromMap(e)).toList();
    if(ProductData.length>0){return ProductData[0];}
    return null;
  }
  //استعلام بناء على المعرف
  Future<ProductModel?>GetById(int id)async{

    List<Map<String,dynamic>> product=await DatabaseService.instance.GetById(table,id);
    List<ProductModel>result=product.map((e)=> ProductModel.fromMap(e)).toList();
    if(result.length>0){return result.first;}
    return null;
  }
}