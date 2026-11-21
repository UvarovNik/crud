from decimal import Decimal
from django.test import TestCase, Client
from django.urls import reverse
from logistic.models import Product, Stock, StockProduct


class ProductAPITestCase(TestCase):
    def setUp(self):
        self.client = Client()
        self.product_data = {
            "title": "Tomato",
            "description": "Fresh tomatoes"
        }

    def test_create_product(self):
        response = self.client.post(
            '/api/v1/products/',
            self.product_data,
            content_type='application/json'
        )
        self.assertEqual(response.status_code, 201)
        self.assertEqual(Product.objects.count(), 1)

    def test_list_products(self):
        Product.objects.create(**self.product_data)
        response = self.client.get('/api/v1/products/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.json()['results']), 1)

    def test_search_products(self):
        Product.objects.create(**self.product_data)
        response = self.client.get('/api/v1/products/?search=tomato')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.json()['results']), 1)

    def test_update_product(self):
        product = Product.objects.create(**self.product_data)
        update_data = {
            "title": "Tomato",
            "description": "Updated description"
        }
        response = self.client.patch(
            f'/api/v1/products/{product.id}/',
            update_data,
            content_type='application/json'
        )
        self.assertEqual(response.status_code, 200)
        product.refresh_from_db()
        self.assertEqual(product.description, "Updated description")

    def test_delete_product(self):
        product = Product.objects.create(**self.product_data)
        response = self.client.delete(f'/api/v1/products/{product.id}/')
        self.assertEqual(response.status_code, 204)
        self.assertEqual(Product.objects.count(), 0)


class StockAPITestCase(TestCase):
    def setUp(self):
        self.client = Client()
        self.product = Product.objects.create(
            title="Tomato",
            description="Fresh"
        )
        self.stock_data = {
            "address": "123 Main St",
            "positions": [
                {"product": self.product.id, "quantity": 100, "price": "10.00"}
            ]
        }

    def test_create_stock(self):
        response = self.client.post(
            '/api/v1/stocks/',
            self.stock_data,
            content_type='application/json'
        )
        self.assertEqual(response.status_code, 201)
        self.assertEqual(Stock.objects.count(), 1)

    def test_list_stocks(self):
        Stock.objects.create(address="123 Main St")
        response = self.client.get('/api/v1/stocks/')
        self.assertEqual(response.status_code, 200)

    def test_update_stock_positions(self):
        stock = Stock.objects.create(address="123 Main St")
        StockProduct.objects.create(
            stock=stock,
            product=self.product,
            quantity=50,
            price="15.00"
        )
        update_data = {
            "address": "123 Main St",
            "positions": [
                {"product": self.product.id, "quantity": 100, "price": "10.00"}
            ]
        }
        response = self.client.patch(
            f'/api/v1/stocks/{stock.id}/',
            update_data,
            content_type='application/json'
        )
        self.assertEqual(response.status_code, 200)
        position = StockProduct.objects.get(stock=stock, product=self.product)
        self.assertEqual(position.quantity, 100)
        self.assertEqual(position.price, Decimal("10.00"))

    def test_delete_stock(self):
        stock = Stock.objects.create(address="123 Main St")
        response = self.client.delete(f'/api/v1/stocks/{stock.id}/')
        self.assertEqual(response.status_code, 204)
        self.assertEqual(Stock.objects.count(), 0)
