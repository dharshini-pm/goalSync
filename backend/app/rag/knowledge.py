"""Curated seed merchant and category knowledge dataset for vector retrieval."""

from typing import List
from .models import MerchantKnowledgeDocument

SEED_MERCHANT_DOCUMENTS: List[MerchantKnowledgeDocument] = [
    MerchantKnowledgeDocument(
        merchant_name="Swiggy",
        aliases=["SWIGGY", "SWIGGY IN", "BUNDL TECHNOLOGIES"],
        category="Food",
        description="Online food ordering, grocery delivery, and restaurant delivery service",
        keywords=["food delivery", "restaurant", "meals", "groceries", "instamart", "takeaway", "food order", "pizza"],
    ),
    MerchantKnowledgeDocument(
        merchant_name="Zomato",
        aliases=["ZOMATO", "ZOMATO LTD", "ZOMATO ORDER"],
        category="Food",
        description="Online restaurant discovery, dining booking, food ordering and delivery platform",
        keywords=["food delivery", "restaurant", "dining", "order food", "meals", "pizza order", "lunch", "dinner"],
    ),
    MerchantKnowledgeDocument(
        merchant_name="Amazon",
        aliases=["AMAZON", "AMZN", "AMAZON PAY", "AMAZON INDIA"],
        category="Shopping",
        description="E-commerce marketplace for online shopping, electronics, clothing, and digital services",
        keywords=["online shopping", "ecommerce", "retail", "orders", "marketplace", "goods"],
    ),
    MerchantKnowledgeDocument(
        merchant_name="Flipkart",
        aliases=["FLIPKART", "FKRT", "FLIPKART INTERNET"],
        category="Shopping",
        description="Indian e-commerce platform offering online shopping across electronics, fashion, and home goods",
        keywords=["online shopping", "ecommerce", "fashion", "electronics", "retail", "products"],
    ),
    MerchantKnowledgeDocument(
        merchant_name="Uber",
        aliases=["UBER", "UBER INDIA", "UBER TRIP", "UBER RIDES"],
        category="Transport",
        description="Ridesharing and on-demand mobility platform for taxi cabs, autos, and car rides",
        keywords=["transport", "cab", "taxi", "ride sharing", "commute", "travel", "auto ride"],
    ),
    MerchantKnowledgeDocument(
        merchant_name="Ola",
        aliases=["OLA", "OLA CABS", "ANI TECHNOLOGIES"],
        category="Transport",
        description="On-demand ride hailing and cab booking service for city commute and outstation travel",
        keywords=["transport", "cab booking", "taxi", "ride hailing", "auto", "commute"],
    ),
    MerchantKnowledgeDocument(
        merchant_name="Netflix",
        aliases=["NETFLIX", "NETFLIX ENTERTAINMENT", "NETFLIX COM"],
        category="Entertainment",
        description="Subscription streaming entertainment service for movies, TV series, and documentaries",
        keywords=["entertainment", "streaming", "movies", "tv shows", "subscription", "video"],
    ),
    MerchantKnowledgeDocument(
        merchant_name="Spotify",
        aliases=["SPOTIFY", "SPOTIFY INDIA", "SPOTIFY AB"],
        category="Entertainment",
        description="Digital music, podcast, and audio streaming subscription service",
        keywords=["entertainment", "music", "songs", "podcasts", "audio streaming", "playlist"],
    ),
    MerchantKnowledgeDocument(
        merchant_name="Electricity Board",
        aliases=["BESCOM", "TNEB", "MSEB", "UPPCL", "ELECTRICITY BILL"],
        category="Utilities",
        description="Public and private electricity distribution and utility power billing service",
        keywords=["utilities", "electricity", "power", "utility bill", "electric payment", "energy"],
    ),
    MerchantKnowledgeDocument(
        merchant_name="Airtel",
        aliases=["AIRTEL", "BHARTI AIRTEL", "AIRTEL PREPAID", "AIRTEL POSTPAID"],
        category="Utilities",
        description="Telecommunications provider for mobile recharges, broadband internet, and utility services",
        keywords=["utilities", "telecom", "mobile recharge", "broadband", "wifi", "phone bill"],
    ),
    MerchantKnowledgeDocument(
        merchant_name="Jio",
        aliases=["JIO", "RELIANCE JIO", "JIO FIBER", "JIO PREPAID"],
        category="Utilities",
        description="Digital telecom network providing mobile plans, fiber broadband, and data utility services",
        keywords=["utilities", "telecom", "recharge", "broadband", "fiber", "cellular", "internet"],
    ),
]


def get_seed_knowledge_documents() -> List[MerchantKnowledgeDocument]:
    """Returns a fresh copy of the seed merchant knowledge documents."""
    return [
        MerchantKnowledgeDocument(
            merchant_name=doc.merchant_name,
            aliases=list(doc.aliases),
            category=doc.category,
            description=doc.description,
            keywords=list(doc.keywords),
        )
        for doc in SEED_MERCHANT_DOCUMENTS
    ]
